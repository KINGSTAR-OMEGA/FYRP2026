import 'dart:io';
import 'dart:ui';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../models/course_model.dart';
import '../../models/lesson_model.dart';
import '../../models/phase_model.dart';
import '../../models/progress_model.dart';
import '../../models/question_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/progress_provider.dart';
import '../../services/ai_service.dart';
import '../../services/smart_pause_service.dart';
import '../../services/storage_service.dart';
import '../../utils/theme.dart';
import '../../widgets/student/ai_chat_panel.dart';
import '../../widgets/student/phase_question_overlay.dart';

class VideoLearningScreen extends StatefulWidget {
  final CourseModel course;
  final LessonModel lesson;

  const VideoLearningScreen({
    super.key,
    required this.course,
    required this.lesson,
  });

  @override
  State<VideoLearningScreen> createState() => _VideoLearningScreenState();
}

class _VideoLearningScreenState extends State<VideoLearningScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _videoInitialized = false;
  bool _videoError = false;

  PhaseModel? _activePhase;
  final Set<String> _shownPhases = {};
  bool _overlayVisible = false;

  // AI question generation state
  final AiService _ai = AiService();
  final StorageService _storage = StorageService();
  bool _generatingQuestions = false;
  List<QuestionModel>? _pendingAiQuestions;
  String _lastPerformanceInsight = '';

  late String _userId;
  late TabController _tabCtrl;
  final FullscreenChangeNotifier _fullscreenNotifier = FullscreenChangeNotifier();

  SmartPauseService? _smartPauseService;
  bool _smartPauseEnabled = false;
  DetectorState _smartPauseState = DetectorState.disabled;
  int? _smartPauseSecondsLeft;

  void _initSmartPause() {
    _smartPauseService = SmartPauseService(
      onStateChanged: (state, {secondsLeft}) {
        if (!mounted) return;
        setState(() {
          _smartPauseState = state;
          _smartPauseSecondsLeft = secondsLeft;
        });
        _fullscreenNotifier.notify();
      },
      onPauseVideo: () {
        if (!mounted) return;
        _pauseVideoBySmartPause();
      },
      onResumeVideo: () {
        if (!mounted) return;
        _resumeVideoBySmartPause();
      },
    );
  }

  void _pauseVideoBySmartPause() {
    if (_videoCtrl != null && _videoCtrl!.value.isPlaying) {
      _videoCtrl!.pause();
      context.read<ProgressProvider>().incrementLookedAwayCount(
            _userId,
            widget.course.id,
            widget.lesson.id,
          );
    }
  }

  void _resumeVideoBySmartPause() {
    if (_videoCtrl != null && !_videoCtrl!.value.isPlaying && !_overlayVisible) {
      _videoCtrl!.play();
    }
  }

  Future<void> _toggleSmartPause(bool enable) async {
    if (enable) {
      if (_smartPauseService == null) {
        _initSmartPause();
      }
      setState(() {
        _smartPauseEnabled = true;
      });
      _fullscreenNotifier.notify();
      await _smartPauseService!.start();
      if (_smartPauseService!.state == DetectorState.permissionDenied) {
        setState(() {
          _smartPauseEnabled = false;
        });
        _fullscreenNotifier.notify();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required for Smart Pause.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
      setState(() {
        _smartPauseEnabled = false;
        _smartPauseState = DetectorState.disabled;
        _smartPauseSecondsLeft = null;
      });
      _fullscreenNotifier.notify();
      await _smartPauseService?.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _userId = context.read<AuthProvider>().currentUser!.id;
    _tabCtrl = TabController(length: 2, vsync: this);

    // Load this student's memory when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MemoryProvider>().loadMemory(_userId);
    });

    _initVideo();
  }

  Future<void> _initVideo() async {
    final path = widget.lesson.videoPath;
    if (path.isEmpty) {
      setState(() => _videoError = true);
      return;
    }

    try {
      if (path.startsWith('content://')) {
        _videoCtrl = VideoPlayerController.contentUri(Uri.parse(path));
      } else {
        final file = File(path);
        if (!await file.exists()) {
          setState(() => _videoError = true);
          return;
        }
        _videoCtrl = VideoPlayerController.file(file);
      }
      await _videoCtrl!.initialize();

      if (!mounted) return;
      final progress = context.read<ProgressProvider>();
      final lp = progress.getLessonProgress(
          _userId, widget.course.id, widget.lesson.id);
      if (lp.watchedSeconds > 0) {
        await _videoCtrl!.seekTo(
            Duration(milliseconds: (lp.watchedSeconds * 1000).toInt()));
      }

      _shownPhases.addAll(lp.completedPhaseIds);

      _chewieCtrl = ChewieController(
        videoPlayerController: _videoCtrl!,
        autoPlay: false,
        looping: false,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: AppColors.border,
          bufferedColor: AppColors.primaryLight,
        ),
        routePageBuilder: (context, animation, secondaryAnimation, controllerProvider) {
          return ListenableBuilder(
            listenable: _fullscreenNotifier,
            builder: (context, child) {
              return Scaffold(
                backgroundColor: Colors.black,
                resizeToAvoidBottomInset: true,
                body: _FullscreenVideoLayout(
                  controllerProvider: controllerProvider,
                  videoLearningScreenState: this,
                ),
              );
            },
          );
        },
      );

      _videoCtrl!.addListener(_onVideoProgress);

      if (mounted) {
        setState(() => _videoInitialized = true);
        _fullscreenNotifier.notify();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _videoError = true);
        _fullscreenNotifier.notify();
      }
    }
  }

  void _onVideoProgress() {
    if (_videoCtrl == null || !_videoCtrl!.value.isInitialized) return;
    if (_overlayVisible) return;

    final pos = _videoCtrl!.value.position.inMilliseconds / 1000.0;

    context.read<ProgressProvider>().updateWatchPosition(
          _userId,
          widget.course.id,
          widget.lesson.id,
          pos,
        );

    for (final phase in widget.lesson.phases) {
      if (!_shownPhases.contains(phase.id) && pos >= phase.endTimeSeconds) {
        _triggerPhase(phase);
        return;
      }
    }

    final duration = _videoCtrl!.value.duration.inSeconds.toDouble();
    if (duration > 0 && pos >= duration - 1.0) {
      _completeLesson();
    }
  }

  Future<void> _triggerPhase(PhaseModel phase) async {
    _videoCtrl?.pause();

    // Capture memory before any await to avoid BuildContext-across-async-gap lint
    final memory = context.read<MemoryProvider>().getMemory(_userId);

    // Check SharedPreferences cache first — instant load, no spinner
    final cached = await _storage.loadCachedAiQuestions(
        widget.lesson.id, phase.id, _userId);

    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _activePhase = phase;
        _pendingAiQuestions = cached;
        _generatingQuestions = false;
        _overlayVisible = true;
      });
      _fullscreenNotifier.notify();
      return;
    }

    // Show overlay with loading spinner while Grok generates questions
    setState(() {
      _activePhase = phase;
      _pendingAiQuestions = null;
      _generatingQuestions = true;
      _overlayVisible = true;
    });
    _fullscreenNotifier.notify();

    final duration = _videoCtrl?.value.duration.inSeconds.toDouble() ?? 600.0;

    final generated = await _ai.generatePhaseQuestions(
      transcription: widget.lesson.transcription,
      phaseTitle: phase.title,
      videoDurationSeconds: duration,
      lessonTitle: widget.lesson.title,
      studentMemory: memory,
    );

    if (!mounted) return;

    // Cache successful generations
    if (generated != null && generated.isNotEmpty) {
      await _storage.saveCachedAiQuestions(
          widget.lesson.id, phase.id, _userId, generated);
    }

    setState(() {
      _generatingQuestions = false;
      _pendingAiQuestions = generated; // null → overlay falls back to admin Qs
    });
    _fullscreenNotifier.notify();
  }

  void _onPhaseComplete() {
    if (_activePhase != null) _shownPhases.add(_activePhase!.id);
    setState(() {
      _overlayVisible = false;
      _activePhase = null;
      _pendingAiQuestions = null;
    });
    _fullscreenNotifier.notify();
    _videoCtrl?.play();
  }

  void _onPhaseResults(String phaseId, int correct, int total) {
    context.read<ProgressProvider>().recordPhaseResult(
          _userId,
          widget.course.id,
          widget.lesson.id,
          PhaseResult(
            phaseId: phaseId,
            correct: correct,
            total: total,
            completedAt: DateTime.now(),
          ),
        );

    // Fire-and-forget: fetch AI performance insight for the summary card
    if (_activePhase != null) {
      _fetchPerformanceInsight(
        phaseTitle: _activePhase!.title,
        correct: correct,
        total: total,
      );
    }
  }

  Future<void> _fetchPerformanceInsight({
    required String phaseTitle,
    required int correct,
    required int total,
  }) async {
    final memory = context.read<MemoryProvider>().getMemory(_userId);
    final insight = await _ai.analyzePerformance(
      memory: memory,
      recentPhaseTitle: phaseTitle,
      recentCorrect: correct,
      recentTotal: total,
    );
    if (!mounted) return;
    setState(() => _lastPerformanceInsight = insight);
    _fullscreenNotifier.notify();

    await context.read<MemoryProvider>().recordAiReview(
          studentId: _userId,
          phaseTitle: phaseTitle,
          review: insight,
        );
  }

  void _completeLesson() {
    context.read<ProgressProvider>().completeLesson(
          _userId,
          widget.course.id,
          widget.lesson.id,
        );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    if (_videoCtrl != null && _videoCtrl!.value.isInitialized) {
      _videoCtrl!.removeListener(_onVideoProgress);
      // Force write last watched position to database on screen exit
      final pos = _videoCtrl!.value.position.inMilliseconds / 1000.0;
      context.read<ProgressProvider>().updateWatchPosition(
            _userId,
            widget.course.id,
            widget.lesson.id,
            pos,
            force: true,
          );
    }
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    _smartPauseService?.dispose();
    _fullscreenNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final chatHistory = progress
        .getLessonProgress(_userId, widget.course.id, widget.lesson.id)
        .chatHistory;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        toolbarHeight: 60,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.course.title,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.textLow,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.lesson.title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHigh,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (widget.lesson.phases.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.lesson.phases.map((p) {
                  final done = _shownPhases.contains(p.id);
                  return Container(
                    margin: const EdgeInsets.only(left: 4),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.success : AppColors.border,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
        actions: [
          _buildSmartPauseToggle(),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      flex: 65,
                      child: _VideoSide(
                        videoInitialized: _videoInitialized,
                        videoError: _videoError,
                        chewieCtrl: _chewieCtrl,
                        videoCtrl: _videoCtrl,
                        lesson: widget.lesson,
                        shownPhases: _shownPhases,
                        smartPauseState: _smartPauseState,
                        onResumeTap: () => _toggleSmartPause(false),
                      ),
                    ),
                    SizedBox(
                      width: 360,
                      child: AiChatPanel(
                        courseId: widget.course.id,
                        lessonId: widget.lesson.id,
                        transcription: widget.lesson.transcription,
                        initialMessages: chatHistory,
                      ),
                    ),
                  ],
                );
              }
              return SafeArea(
                top: false,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _VideoPlayer(
                        videoInitialized: _videoInitialized,
                        videoError: _videoError,
                        chewieCtrl: _chewieCtrl,
                        smartPauseState: _smartPauseState,
                        onResumeTap: () => _toggleSmartPause(false),
                      ),
                    ),
                    Container(
                      color: AppColors.bg,
                      child: TabBar(
                        controller: _tabCtrl,
                        labelStyle: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13),
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textMed,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 2,
                        tabs: const [
                          Tab(text: 'Lesson'),
                          Tab(text: 'AI Chat'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _LessonInfoPanel(
                            lesson: widget.lesson,
                            shownPhases: _shownPhases,
                          ),
                          AiChatPanel(
                            courseId: widget.course.id,
                            lessonId: widget.lesson.id,
                            transcription: widget.lesson.transcription,
                            initialMessages: chatHistory,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Phase question overlay — with AI loading + generated questions
          if (_overlayVisible && _activePhase != null)
            PhaseQuestionOverlay(
              phase: _activePhase!,
              aiQuestions: _pendingAiQuestions,
              isLoadingQuestions: _generatingQuestions,
              performanceInsight: _lastPerformanceInsight,
              onComplete: _onPhaseComplete,
              onResults: (c, t) =>
                  _onPhaseResults(_activePhase!.id, c, t),
              onAnswered: (topic, wasCorrect) {
                context.read<MemoryProvider>().recordAnswer(
                      studentId: _userId,
                      topic: topic,
                      wasCorrect: wasCorrect,
                    );
              },
            ).animate().fadeIn(duration: 250.ms),
        ],
      ),
    );
  }

  Widget _buildSmartPauseToggle() {
    Color iconColor = AppColors.textLow;
    Color bgColor = AppColors.bgSurface;
    Color borderColor = AppColors.border;
    IconData iconData = Icons.visibility_off_outlined;
    String label = 'Smart Pause';

    if (_smartPauseEnabled) {
      switch (_smartPauseState) {
        case DetectorState.initializing:
          iconColor = AppColors.primary;
          iconData = Icons.hourglass_empty;
          label = 'Starting...';
          break;
        case DetectorState.permissionDenied:
          iconColor = AppColors.error;
          iconData = Icons.videocam_off_outlined;
          label = 'Blocked';
          break;
        case DetectorState.watching:
          iconColor = AppColors.success;
          iconData = Icons.visibility_outlined;
          label = 'Active';
          borderColor = AppColors.success.withValues(alpha: 0.5);
          bgColor = AppColors.success.withValues(alpha: 0.05);
          break;
        case DetectorState.notPresentCountDown:
        case DetectorState.lookingAwayCountDown:
          iconColor = AppColors.warning;
          iconData = Icons.visibility_outlined;
          label = 'Pausing in ${_smartPauseSecondsLeft ?? 10}s';
          borderColor = AppColors.warning.withValues(alpha: 0.5);
          bgColor = AppColors.warning.withValues(alpha: 0.05);
          break;
        case DetectorState.pausedNotPresent:
        case DetectorState.pausedLookingAway:
          iconColor = AppColors.error;
          iconData = Icons.visibility_off_outlined;
          label = 'Paused';
          borderColor = AppColors.error.withValues(alpha: 0.5);
          bgColor = AppColors.error.withValues(alpha: 0.05);
          break;
        default:
          iconColor = AppColors.primary;
          iconData = Icons.visibility_outlined;
          label = 'Smart Pause';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        onTap: () => _toggleSmartPause(!_smartPauseEnabled),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: _smartPauseEnabled && _smartPauseState == DetectorState.watching
                ? [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.15),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iconData,
                size: 14,
                color: iconColor,
              ).animate(
                target: (_smartPauseState == DetectorState.notPresentCountDown ||
                        _smartPauseState == DetectorState.lookingAwayCountDown)
                    ? 1
                    : 0,
              ).scaleXY(begin: 1.0, end: 1.15, duration: 400.ms).then().shake(duration: 400.ms),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _smartPauseEnabled ? iconColor : AppColors.textMed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Supporting widgets (unchanged from original) ─────────────────────────────

class _VideoSide extends StatelessWidget {
  final bool videoInitialized;
  final bool videoError;
  final ChewieController? chewieCtrl;
  final VideoPlayerController? videoCtrl;
  final LessonModel lesson;
  final Set<String> shownPhases;
  final DetectorState smartPauseState;
  final VoidCallback onResumeTap;

  const _VideoSide({
    required this.videoInitialized,
    required this.videoError,
    required this.chewieCtrl,
    required this.videoCtrl,
    required this.lesson,
    required this.shownPhases,
    required this.smartPauseState,
    required this.onResumeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _VideoPlayer(
            videoInitialized: videoInitialized,
            videoError: videoError,
            chewieCtrl: chewieCtrl,
            smartPauseState: smartPauseState,
            onResumeTap: onResumeTap,
          ),
        ),
        if (lesson.phases.isNotEmpty)
          _PhaseTimeline(
            phases: lesson.phases,
            shownPhases: shownPhases,
            videoDuration:
                videoCtrl?.value.duration.inSeconds.toDouble() ?? 0,
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHigh,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _InfoChip(
                        icon: Icons.segment,
                        label: '${lesson.phases.length} phases'),
                    const SizedBox(width: 8),
                    _InfoChip(
                        icon: Icons.check_circle_outline,
                        label:
                            '${shownPhases.length}/${lesson.phases.length} completed'),
                  ],
                ),
                if (lesson.phases.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Video Phases',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...lesson.phases.map(
                    (p) => _PhaseInfoRow(
                      phase: p,
                      done: shownPhases.contains(p.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoPlayer extends StatelessWidget {
  final bool videoInitialized;
  final bool videoError;
  final ChewieController? chewieCtrl;
  final DetectorState smartPauseState;
  final VoidCallback onResumeTap;

  const _VideoPlayer({
    required this.videoInitialized,
    required this.videoError,
    required this.chewieCtrl,
    required this.smartPauseState,
    required this.onResumeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (videoError) {
      return Container(
        color: const Color(0xFF0A0A14),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.video_file_outlined,
                  color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text('Video not available',
                  style:
                      GoogleFonts.outfit(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 4),
              Text('The video file could not be found.',
                  style: GoogleFonts.outfit(
                      color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (!videoInitialized) {
      return Container(
        color: const Color(0xFF0A0A14),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    final isPausedBySmartPause = smartPauseState == DetectorState.pausedNotPresent ||
        smartPauseState == DetectorState.pausedLookingAway;

    Widget player = Container(
      color: Colors.black,
      child: Chewie(controller: chewieCtrl!),
    );

    if (!isPausedBySmartPause) {
      return player;
    }

    String warningTitle = "Video Paused";
    String warningDesc = "Please look at the screen to continue.";
    IconData warningIcon = Icons.visibility_off_rounded;
    Color warningColor = AppColors.warning;

    if (smartPauseState == DetectorState.pausedNotPresent) {
      warningTitle = "No Viewer Detected";
      warningDesc = "We couldn't see you. Face the camera to resume.";
      warningIcon = Icons.person_off_rounded;
      warningColor = AppColors.error;
    } else if (smartPauseState == DetectorState.pausedLookingAway) {
      warningTitle = "Are you watching?";
      warningDesc = "Video paused because you looked away.";
      warningIcon = Icons.visibility_off_rounded;
      warningColor = AppColors.warning;
    }

    return Stack(
      children: [
        player,
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: warningColor.withValues(alpha: 0.15),
                            border: Border.all(
                              color: warningColor.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            warningIcon,
                            color: warningColor,
                            size: 32,
                          ),
                        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                         .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds)
                         .boxShadow(
                           begin: BoxShadow(color: warningColor.withValues(alpha: 0.1), blurRadius: 10),
                           end: BoxShadow(color: warningColor.withValues(alpha: 0.3), blurRadius: 20),
                         ),
                        const SizedBox(height: 12),
                        Text(
                          warningTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          warningDesc,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Detecting face to auto-resume...",
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: Colors.white54,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: onResumeTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.textHigh,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text("Resume Manually"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhaseTimeline extends StatelessWidget {
  final List<PhaseModel> phases;
  final Set<String> shownPhases;
  final double videoDuration;

  const _PhaseTimeline({
    required this.phases,
    required this.shownPhases,
    required this.videoDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Text('Phases: ',
              style:
                  GoogleFonts.outfit(fontSize: 11, color: AppColors.textLow)),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (videoDuration > 0)
                  ...phases.map((p) {
                    final frac =
                        (p.endTimeSeconds / videoDuration).clamp(0.02, 0.98);
                    return Align(
                      alignment: Alignment(frac * 2 - 1, 0),
                      child: Tooltip(
                        message:
                            '${p.title} (${p.endTimeSeconds.toStringAsFixed(0)}s)',
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: shownPhases.contains(p.id)
                                ? AppColors.success
                                : AppColors.primary,
                            border:
                                Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: (shownPhases.contains(p.id)
                                        ? AppColors.success
                                        : AppColors.primary)
                                    .withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseInfoRow extends StatelessWidget {
  final PhaseModel phase;
  final bool done;

  const _PhaseInfoRow({required this.phase, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: done ? AppColors.success : AppColors.border,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(phase.title,
                style: GoogleFonts.outfit(
                    fontSize: 13, color: AppColors.textMed)),
          ),
          Text('${phase.endTimeSeconds.toStringAsFixed(0)}s',
              style: GoogleFonts.outfit(
                  fontSize: 11, color: AppColors.textLow)),
          const SizedBox(width: 8),
          Text('${phase.questions.length} Q',
              style: GoogleFonts.outfit(
                  fontSize: 11, color: AppColors.textLow)),
        ],
      ),
    );
  }
}

class _LessonInfoPanel extends StatelessWidget {
  final LessonModel lesson;
  final Set<String> shownPhases;

  const _LessonInfoPanel(
      {required this.lesson, required this.shownPhases});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.title,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textHigh,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _InfoChip(
                  icon: Icons.segment,
                  label: '${lesson.phases.length} phases'),
              _InfoChip(
                  icon: Icons.check_circle_outline,
                  label: '${shownPhases.length}/${lesson.phases.length} done'),
            ],
          ),
          if (lesson.phases.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Phases',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHigh,
                )),
            const SizedBox(height: 8),
            ...lesson.phases.map(
              (p) =>
                  _PhaseInfoRow(phase: p, done: shownPhases.contains(p.id)),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textLow),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppColors.textMed)),
        ],
      ),
    );
  }
}

class FullscreenChangeNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

class _FullscreenVideoLayout extends StatefulWidget {
  final Widget controllerProvider;
  final _VideoLearningScreenState videoLearningScreenState;

  const _FullscreenVideoLayout({
    required this.controllerProvider,
    required this.videoLearningScreenState,
  });

  @override
  State<_FullscreenVideoLayout> createState() => _FullscreenVideoLayoutState();
}

class _FullscreenVideoLayoutState extends State<_FullscreenVideoLayout> {
  bool _chatOpen = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.videoLearningScreenState;
    final isPausedBySmartPause = state._smartPauseState == DetectorState.pausedNotPresent ||
        state._smartPauseState == DetectorState.pausedLookingAway;

    final progress = context.watch<ProgressProvider>();
    final chatHistory = progress
        .getLessonProgress(
          state._userId,
          state.widget.course.id,
          state.widget.lesson.id,
        )
        .chatHistory;

    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              child: widget.controllerProvider,
            ),
            if (_chatOpen)
              SizedBox(
                width: 320,
                child: AiChatPanel(
                  courseId: state.widget.course.id,
                  lessonId: state.widget.lesson.id,
                  transcription: state.widget.lesson.transcription,
                  initialMessages: chatHistory,
                  onClose: () {
                    setState(() {
                      _chatOpen = false;
                    });
                  },
                ),
              ),
          ],
        ),
        if (!_chatOpen && !state._overlayVisible && !isPausedBySmartPause)
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _chatOpen = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Ask AI',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (state._overlayVisible && state._activePhase != null)
          Positioned.fill(
            child: PhaseQuestionOverlay(
              phase: state._activePhase!,
              aiQuestions: state._pendingAiQuestions,
              isLoadingQuestions: state._generatingQuestions,
              performanceInsight: state._lastPerformanceInsight,
              onComplete: state._onPhaseComplete,
              onResults: (c, t) =>
                  state._onPhaseResults(state._activePhase!.id, c, t),
              onAnswered: (topic, wasCorrect) {
                context.read<MemoryProvider>().recordAnswer(
                      studentId: state._userId,
                      topic: topic,
                      wasCorrect: wasCorrect,
                    );
              },
            ),
          ),
        if (isPausedBySmartPause)
          Positioned.fill(
            child: _FullscreenSmartPauseWarning(
              smartPauseState: state._smartPauseState,
              onResumeTap: () => state._toggleSmartPause(false),
            ),
          ),
      ],
    );
  }
}

class _FullscreenSmartPauseWarning extends StatelessWidget {
  final DetectorState smartPauseState;
  final VoidCallback onResumeTap;

  const _FullscreenSmartPauseWarning({
    required this.smartPauseState,
    required this.onResumeTap,
  });

  @override
  Widget build(BuildContext context) {
    String warningTitle = "Video Paused";
    String warningDesc = "Please look at the screen to continue.";
    IconData warningIcon = Icons.visibility_off_rounded;
    Color warningColor = AppColors.warning;

    if (smartPauseState == DetectorState.pausedNotPresent) {
      warningTitle = "No Viewer Detected";
      warningDesc = "We couldn't see you. Face the camera to resume.";
      warningIcon = Icons.person_off_rounded;
      warningColor = AppColors.error;
    } else if (smartPauseState == DetectorState.pausedLookingAway) {
      warningTitle = "Are you watching?";
      warningDesc = "Video paused because you looked away.";
      warningIcon = Icons.visibility_off_rounded;
      warningColor = AppColors.warning;
    }

    return Material(
      color: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black.withValues(alpha: 0.65),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: warningColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: warningColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        warningIcon,
                        color: warningColor,
                        size: 32,
                      ),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds)
                     .boxShadow(
                       begin: BoxShadow(color: warningColor.withValues(alpha: 0.1), blurRadius: 10),
                       end: BoxShadow(color: warningColor.withValues(alpha: 0.3), blurRadius: 20),
                     ),
                    const SizedBox(height: 12),
                    Text(
                      warningTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      warningDesc,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Detecting face to auto-resume...",
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: Colors.white54,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: onResumeTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textHigh,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text("Resume Manually"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
