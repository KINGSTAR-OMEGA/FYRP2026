import 'dart:io';
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
      );

      _videoCtrl!.addListener(_onVideoProgress);

      if (mounted) setState(() => _videoInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _videoError = true);
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
      return;
    }

    // Show overlay with loading spinner while Grok generates questions
    setState(() {
      _activePhase = phase;
      _pendingAiQuestions = null;
      _generatingQuestions = true;
      _overlayVisible = true;
    });

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
  }

  void _onPhaseComplete() {
    if (_activePhase != null) _shownPhases.add(_activePhase!.id);
    setState(() {
      _overlayVisible = false;
      _activePhase = null;
      _pendingAiQuestions = null;
    });
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
    _videoCtrl?.removeListener(_onVideoProgress);
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
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
}

// ─── Supporting widgets (unchanged from original) ─────────────────────────────

class _VideoSide extends StatelessWidget {
  final bool videoInitialized;
  final bool videoError;
  final ChewieController? chewieCtrl;
  final VideoPlayerController? videoCtrl;
  final LessonModel lesson;
  final Set<String> shownPhases;

  const _VideoSide({
    required this.videoInitialized,
    required this.videoError,
    required this.chewieCtrl,
    required this.videoCtrl,
    required this.lesson,
    required this.shownPhases,
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

  const _VideoPlayer({
    required this.videoInitialized,
    required this.videoError,
    required this.chewieCtrl,
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

    return Container(
      color: Colors.black,
      child: Chewie(controller: chewieCtrl!),
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
