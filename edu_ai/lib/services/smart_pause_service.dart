import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

enum DetectorState {
  disabled,
  initializing,
  permissionDenied,
  watching,
  notPresentCountDown,
  lookingAwayCountDown,
  pausedNotPresent,
  pausedLookingAway,
}

class SmartPauseService {
  static const int _frameIntervalMs = 1200; // Process 1 frame every 1.2s (saves CPU & battery)
  static const int _requiredNotWatchingFrames = 8; // 8 * 1.2s = 9.6s (~10s continuous check)
  static const int _requiredWatchingFrames = 1;    // 1 * 1.2s = 1.2s (~1s stable check)

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  CameraDescription? _cameraDescription;
  
  bool _isProcessing = false;
  DateTime? _lastProcessedTime;
  
  int _notWatchingFrames = 0;
  int _watchingFrames = 0;
  
  DetectorState _state = DetectorState.disabled;
  DetectorState get state => _state;

  final Function(DetectorState state, {int? secondsLeft}) onStateChanged;
  final VoidCallback onPauseVideo;
  final VoidCallback onResumeVideo;

  SmartPauseService({
    required this.onStateChanged,
    required this.onPauseVideo,
    required this.onResumeVideo,
  });

  Future<void> start() async {
    if (_state != DetectorState.disabled && _state != DetectorState.permissionDenied) {
      return;
    }

    _state = DetectorState.initializing;
    onStateChanged(_state);
    if (kDebugMode) {
      print('[SmartPause] 📸 Requesting camera permission...');
    }

    // 1. Request Permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _state = DetectorState.permissionDenied;
      onStateChanged(_state);
      if (kDebugMode) {
        print('[SmartPause] 🚫 Camera permission was denied.');
      }
      return;
    }

    try {
      // 2. Find Front Camera
      final cameras = await availableCameras();
      _cameraDescription = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => throw Exception('Front camera not found'),
      );
      if (kDebugMode) {
        print('[SmartPause] 🔍 Found front camera: ${_cameraDescription!.name}');
      }

      // 3. Initialize Camera Controller (High resolution is used to reliably detect face at typical viewing distance)
      _cameraController = CameraController(
        _cameraDescription!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.nv21 
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (kDebugMode) {
        print('[SmartPause] 🎥 Camera controller initialized successfully.');
      }

      // 4. Initialize Face Detector (Accurate mode for distant detection, classifications disabled to save CPU)
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableClassification: false,
          enableLandmarks: false,
          enableTracking: false,
        ),
      );
      if (kDebugMode) {
        print('[SmartPause] 🧠 FaceDetector initialized.');
      }

      _state = DetectorState.watching;
      _notWatchingFrames = 0;
      _watchingFrames = 0;
      onStateChanged(_state);

      // 5. Start Image Stream
      await _cameraController!.startImageStream(_handleCameraImage);
      if (kDebugMode) {
        print('[SmartPause] 🟢 Camera image stream started.');
      }
    } catch (e) {
      debugPrint('Error starting SmartPauseService: $e');
      _state = DetectorState.disabled;
      onStateChanged(_state);
      _cleanup();
    }
  }

  void _handleCameraImage(CameraImage image) async {
    if (_state == DetectorState.disabled || 
        _state == DetectorState.permissionDenied || 
        _state == DetectorState.initializing) {
      return;
    }

    final now = DateTime.now();
    // Throttle: Process 1 frame every _frameIntervalMs
    if (_lastProcessedTime != null && 
        now.difference(_lastProcessedTime!) < const Duration(milliseconds: _frameIntervalMs)) {
      return;
    }

    if (_isProcessing) {
      if (kDebugMode) {
        print('[SmartPause] ⏳ Skipped frame: detector is busy processing a previous frame.');
      }
      return;
    }
    _isProcessing = true;
    _lastProcessedTime = now;

    try {
      if (kDebugMode) {
        print('[SmartPause] 🖼️ Processing incoming camera frame...');
      }
      final inputImage = _inputImageFromCameraImage(image, _cameraDescription!);
      if (inputImage != null && _faceDetector != null) {
        final faces = await _faceDetector!.processImage(inputImage);
        _processFaces(faces);
      } else {
        if (kDebugMode) {
          print('[SmartPause] ❌ Conversion to InputImage failed or detector was disposed.');
        }
      }
    } catch (e) {
      debugPrint('Error running face detection: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _processFaces(List<Face> faces) {
    if (_state == DetectorState.disabled || 
        _state == DetectorState.permissionDenied || 
        _state == DetectorState.initializing) {
      return;
    }

    bool isWatching = false;
    DetectorState frameState = DetectorState.watching;

    if (faces.isNotEmpty) {
      final face = faces.first;
      
      final double yaw = face.headEulerAngleY ?? 0.0;
      final double pitch = face.headEulerAngleX ?? 0.0;

      // Thresholds:
      // Yaw > 55 degrees (extremely loose check for head turned left/right)
      // Pitch > 45 or < -45 degrees (extremely loose check for looking far up/down)
      // Eye openness check is disabled to prevent distance/lighting false positives
      bool lookingAway = yaw.abs() > 55 || pitch.abs() > 45;

      if (lookingAway) {
        isWatching = false;
        frameState = DetectorState.lookingAwayCountDown;
      } else {
        isWatching = true;
        frameState = DetectorState.watching;
      }

      if (kDebugMode) {
        print('[SmartPause] 👀 Face metrics - Yaw: ${yaw.toStringAsFixed(1)}°, Pitch: ${pitch.toStringAsFixed(1)}° | lookingAway: $lookingAway, isWatching: $isWatching');
      }
    } else {
      isWatching = false;
      frameState = DetectorState.notPresentCountDown;
      if (kDebugMode) {
        print('[SmartPause] ❓ No face detected in this frame.');
      }
    }

    if (isWatching) {
      _notWatchingFrames = 0;
      _watchingFrames++;

      if (_state == DetectorState.pausedNotPresent || _state == DetectorState.pausedLookingAway) {
        if (kDebugMode) {
          print('[SmartPause] 🔙 User returned. Stable watching frames: $_watchingFrames/$_requiredWatchingFrames');
        }
        if (_watchingFrames >= _requiredWatchingFrames) {
          if (kDebugMode) {
            print('[SmartPause] ▶️ Stable attention detected. Triggering RESUME.');
          }
          _state = DetectorState.watching;
          _watchingFrames = 0;
          onResumeVideo();
          onStateChanged(_state);
        }
      } else if (_state != DetectorState.watching) {
        if (kDebugMode) {
          print('[SmartPause] 👤 User is looking. State: watching.');
        }
        _state = DetectorState.watching;
        onStateChanged(_state);
      }
    } else {
      _watchingFrames = 0;
      _notWatchingFrames++;

      if (kDebugMode) {
        print('[SmartPause] 📭 User not watching. Consecutive frames: $_notWatchingFrames/$_requiredNotWatchingFrames');
      }

      if (_state == DetectorState.pausedNotPresent || _state == DetectorState.pausedLookingAway) {
        final nextState = frameState == DetectorState.notPresentCountDown 
            ? DetectorState.pausedNotPresent 
            : DetectorState.pausedLookingAway;
        if (_state != nextState) {
          _state = nextState;
          onStateChanged(_state);
        }
      } else {
        if (_notWatchingFrames >= _requiredNotWatchingFrames) {
          _state = frameState == DetectorState.notPresentCountDown 
              ? DetectorState.pausedNotPresent 
              : DetectorState.pausedLookingAway;
          _notWatchingFrames = 0;
          if (kDebugMode) {
            print('[SmartPause] ⏸️ Attention lost. Triggering PAUSE.');
          }
          onPauseVideo();
          onStateChanged(_state);
        } else {
          final countdownState = frameState == DetectorState.notPresentCountDown 
              ? DetectorState.notPresentCountDown 
              : DetectorState.lookingAwayCountDown;
          _state = countdownState;
          
          final secondsLeft = 10.0 - (_notWatchingFrames * (_frameIntervalMs / 1000.0));
          if (kDebugMode) {
            print('[SmartPause] ⏱️ Attention lost. Pausing in ${secondsLeft.toStringAsFixed(1)} seconds...');
          }
          onStateChanged(_state, secondsLeft: secondsLeft.ceil().clamp(1, 10));
        }
      }
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      
      final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) 
          ?? InputImageRotation.rotation0deg;

      final format = Platform.isAndroid 
          ? InputImageFormat.nv21 
          : InputImageFormat.bgra8888;

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  Future<void> stop() async {
    _state = DetectorState.disabled;
    onStateChanged(_state);
    await _cleanup();
  }

  Future<void> _cleanup() async {
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
      } catch (e) {
        debugPrint('Error stopping image stream: $e');
      }
      try {
        await _cameraController!.dispose();
      } catch (e) {
        debugPrint('Error disposing camera controller: $e');
      }
      _cameraController = null;
    }

    if (_faceDetector != null) {
      try {
        await _faceDetector!.close();
      } catch (e) {
        debugPrint('Error closing face detector: $e');
      }
      _faceDetector = null;
    }

    _notWatchingFrames = 0;
    _watchingFrames = 0;
    _isProcessing = false;
  }

  Future<void> dispose() async {
    await stop();
  }
}
