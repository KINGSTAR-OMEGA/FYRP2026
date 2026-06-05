import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../models/lesson_model.dart';
import '../../models/progress_model.dart';
import '../../models/user_model.dart';
import '../../models/student_memory_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/memory_provider.dart';
import '../../utils/theme.dart';

class AdminStudentAnalyticsScreen extends StatefulWidget {
  final UserModel? initialStudent;

  const AdminStudentAnalyticsScreen({super.key, this.initialStudent});

  @override
  State<AdminStudentAnalyticsScreen> createState() =>
      _AdminStudentAnalyticsScreenState();
}

class _AdminStudentAnalyticsScreenState
    extends State<AdminStudentAnalyticsScreen> {
  UserModel? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialStudent;
    if (_selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MemoryProvider>().loadMemory(_selected!.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<AuthProvider>().students;
    if (_selected == null && students.isNotEmpty) {
      _selected = students.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MemoryProvider>().loadMemory(_selected!.id);
      });
    }
    final progress = context.watch<ProgressProvider>();
    final courses = context.watch<CourseProvider>().courses;
    
    final memoryProvider = context.watch<MemoryProvider>();
    final studentMemory = _selected != null ? memoryProvider.getMemory(_selected!.id) : null;

    final List<StudentCourseProgress> studentProgress = _selected != null
        ? progress.getAllProgressForStudent(_selected!.id)
        : [];
    final int completedLessons = _selected != null
        ? progress.getCompletedLessonsCount(_selected!.id)
        : 0;
    final double overallScore = _selected != null
        ? progress.getStudentOverallScore(_selected!.id)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Student Analytics')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 640;

          if (isMobile) {
            // ── Mobile: dropdown picker + scrollable detail below ──────────
            return Column(
              children: [
                // Student picker bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: students.map((s) {
                        final selected = _selected?.id == s.id;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selected = s);
                            context.read<MemoryProvider>().loadMemory(s.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: selected
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : AppColors.primaryLight,
                                  child: Text(
                                    s.initials,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? Colors.white
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  s.name.split(' ').first,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textMed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Detail panel
                Expanded(
                  child: _selected == null
                      ? const Center(child: Text('Select a student'))
                      : _StudentDetailPanel(
                          student: _selected!,
                          completedLessons: completedLessons,
                          overallScore: overallScore,
                          studentProgress: studentProgress,
                          courses: courses.toList(),
                          memory: studentMemory,
                        ),
                ),
              ],
            );
          }

          // ── Wide: sidebar + detail ──────────────────────────────────────
          return Row(
            children: [
              Container(
                width: 220,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Students',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLow,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...students.map(
                      (s) => _StudentListTile(
                        student: s,
                        selected: _selected?.id == s.id,
                        score: progress.getStudentOverallScore(s.id),
                        onTap: () {
                          setState(() => _selected = s);
                          context.read<MemoryProvider>().loadMemory(s.id);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _selected == null
                    ? const Center(child: Text('Select a student'))
                    : _StudentDetailPanel(
                        student: _selected!,
                        completedLessons: completedLessons,
                        overallScore: overallScore,
                        studentProgress: studentProgress,
                        courses: courses.toList(),
                        memory: studentMemory,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentListTile extends StatelessWidget {
  final UserModel student;
  final bool selected;
  final double score;
  final VoidCallback onTap;

  const _StudentListTile({
    required this.student,
    required this.selected,
    required this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  selected ? AppColors.primary : AppColors.bgSurface,
              child: Text(
                student.initials,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textMed,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                student.name.split(' ').first,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textHigh,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentDetailPanel extends StatelessWidget {
  final UserModel student;
  final int completedLessons;
  final double overallScore;
  final List<StudentCourseProgress> studentProgress;
  final List<CourseModel> courses;
  final StudentMemoryModel? memory;

  const _StudentDetailPanel({
    required this.student,
    required this.completedLessons,
    required this.overallScore,
    required this.studentProgress,
    required this.courses,
    this.memory,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (overallScore * 100).round();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Student header
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      student.initials,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHigh,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          student.email,
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.textMed),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(),
              const SizedBox(height: 28),

              // Score overview
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Overall Score',
                      value: overallScore == 0 ? '—' : '$pct%',
                      icon: Icons.star_outline_rounded,
                      color: pct >= 70
                          ? AppColors.success
                          : pct >= 40
                              ? AppColors.warning
                              : AppColors.textLow,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Lessons Done',
                      value: '$completedLessons',
                      icon: Icons.check_circle_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Courses Started',
                      value: '${studentProgress.length}',
                      icon: Icons.play_circle_outline,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ).animate(delay: 100.ms).fadeIn(),
              const SizedBox(height: 28),

              // Cognitive insights (if memory is loaded)
              if (memory != null) ...[
                _CognitiveProfileCard(memory: memory!),
                const SizedBox(height: 16),
                _StrengthsWeaknessesCard(memory: memory!),
                const SizedBox(height: 16),
                _ConfusionPointsCard(memory: memory!),
                const SizedBox(height: 16),
                _AiReviewsCard(memory: memory!),
                const SizedBox(height: 28),
              ],

              // Performance suggestion
              if (overallScore > 0) ...[
                _SuggestionCard(score: overallScore, memory: memory),
                const SizedBox(height: 28),
              ],

              // Course progress
              Text(
                'Course Progress',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHigh,
                ),
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 12),
              if (courses.isEmpty || studentProgress.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      'No course activity yet for this student.',
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: AppColors.textLow),
                    ),
                  ),
                )
              else
                ...studentProgress.map((cp) {
                  final course = courses.where((c) => c.id == cp.courseId).firstOrNull;
                  if (course == null) return const SizedBox.shrink();
                  return _CourseProgressCard(
                    courseName: course.title,
                    lessonProgress: cp,
                    lessons: course.lessons,
                  );
                }),
            ]),
          ),
        ),
      ],
    );
  }
}

class _CognitiveProfileCard extends StatelessWidget {
  final StudentMemoryModel memory;

  const _CognitiveProfileCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    final styleName = memory.learningStyle.toUpperCase();
    final paceName = memory.preferredPace.toUpperCase();

    final Color styleColor;
    final IconData styleIcon;
    final String styleDesc;
    switch (memory.learningStyle.toLowerCase()) {
      case 'conceptual':
        styleColor = AppColors.primary;
        styleIcon = Icons.psychology;
        styleDesc = 'Prefers frameworks, high-level theories, and structured conceptual maps.';
        break;
      case 'visual':
        styleColor = Colors.purple;
        styleIcon = Icons.visibility;
        styleDesc = 'Learns best through diagrams, visual flowcharts, and color-coded information.';
        break;
      case 'example-based':
        styleColor = Colors.teal;
        styleIcon = Icons.menu_book;
        styleDesc = 'Grasps topics fastest when shown concrete code samples, analogies, and case studies.';
        break;
      case 'practice-based':
        styleColor = Colors.orange;
        styleIcon = Icons.fitness_center;
        styleDesc = 'Retains knowledge best through interactive coding exercises, quizzes, and live building.';
        break;
      default:
        styleColor = AppColors.textMed;
        styleIcon = Icons.school;
        styleDesc = 'Standard learning style with balanced conceptual and practical methods.';
    }

    final Color paceColor;
    final IconData paceIcon;
    final String paceDesc;
    switch (memory.preferredPace.toLowerCase()) {
      case 'slow':
        paceColor = Colors.blue;
        paceIcon = Icons.slow_motion_video;
        paceDesc = 'Paces carefully, reviewing sections multiple times. Benefits from extra breakdown steps.';
        break;
      case 'normal':
        paceColor = Colors.green;
        paceIcon = Icons.play_arrow;
        paceDesc = 'Balances review and progression smoothly. Keeps pace with standard curricula.';
        break;
      case 'fast':
        paceColor = Colors.red;
        paceIcon = Icons.speed;
        paceDesc = 'Quickly processes content and prefers direct, high-density explanations.';
        break;
      default:
        paceColor = AppColors.textMed;
        paceIcon = Icons.linear_scale;
        paceDesc = 'Standard pace of content ingestion.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Cognitive & Learning Profile',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textHigh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 650;
              final cards = [
                _CognitiveDetailCard(
                  title: 'Learning Style',
                  value: styleName,
                  description: styleDesc,
                  icon: styleIcon,
                  color: styleColor,
                ),
                _CognitiveDetailCard(
                  title: 'Preferred Pace',
                  value: paceName,
                  description: paceDesc,
                  icon: paceIcon,
                  color: paceColor,
                ),
                _CognitiveDetailCard(
                  title: 'Concept Accuracy',
                  value: '${(memory.overallAccuracy * 100).round()}%',
                  description: 'Overall accuracy across all phase quizzes (${memory.totalCorrect} of ${memory.totalQuestionsAttempted} answers correct).',
                  icon: Icons.track_changes_rounded,
                  color: AppColors.secondary,
                  progressValue: memory.totalQuestionsAttempted == 0 ? 0.0 : memory.overallAccuracy,
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[2]),
                  ],
                );
              } else {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 12),
                    cards[1],
                    const SizedBox(height: 12),
                    cards[2],
                  ],
                );
              }
            },
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _CognitiveDetailCard extends StatelessWidget {
  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color color;
  final double? progressValue;

  const _CognitiveDetailCard({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
    this.progressValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLow,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textMed,
              height: 1.4,
            ),
          ),
          if (progressValue != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StrengthsWeaknessesCard extends StatelessWidget {
  final StudentMemoryModel memory;

  const _StrengthsWeaknessesCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Topic Mastery',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textHigh,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              final content = [
                _TopicListSection(
                  title: 'Strengths (>= 80% accuracy)',
                  topics: memory.strengths,
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                  emptyText: 'No topics mastered yet.',
                ),
                if (!isWide) const SizedBox(height: 16),
                _TopicListSection(
                  title: 'Weaknesses (< 50% accuracy)',
                  topics: memory.weaknesses,
                  color: AppColors.error,
                  icon: Icons.error_outline_rounded,
                  emptyText: 'No major weaknesses identified.',
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: content[0]),
                    const SizedBox(width: 16),
                    Expanded(child: content[2]),
                  ],
                );
              } else {
                return Column(
                  children: [
                    content[0],
                    content[1],
                    content[2],
                  ],
                );
              }
            },
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _TopicListSection extends StatelessWidget {
  final String title;
  final List<String> topics;
  final Color color;
  final IconData icon;
  final String emptyText;

  const _TopicListSection({
    required this.title,
    required this.topics,
    required this.color,
    required this.icon,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMed,
          ),
        ),
        const SizedBox(height: 8),
        if (topics.isEmpty)
          Text(
            emptyText,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.textLow,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topics.map((topic) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 13),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        topic,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textHigh,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _ConfusionPointsCard extends StatelessWidget {
  final StudentMemoryModel memory;

  const _ConfusionPointsCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Confusion Logs',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textHigh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (memory.confusionPoints.isEmpty)
            Text(
              'No confusion points or struggling topics flagged by the AI tutor.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textLow,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: memory.confusionPoints.length,
              itemBuilder: (context, index) {
                final point = memory.confusionPoints[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: CircleAvatar(
                          radius: 3,
                          backgroundColor: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          point,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.textHigh,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _AiReviewsCard extends StatelessWidget {
  final StudentMemoryModel memory;

  const _AiReviewsCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Performance Reviews',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textHigh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (memory.aiReviews.isEmpty)
            Text(
              'No AI performance reviews generated yet. They will appear here once the student completes quiz phases.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textLow,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: memory.aiReviews.length,
              itemBuilder: (context, index) {
                final entry = memory.aiReviews.entries.toList()[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.value,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.textHigh,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textHigh,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMed),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final double score;
  final StudentMemoryModel? memory;

  const _SuggestionCard({required this.score, this.memory});

  @override
  Widget build(BuildContext context) {
    final isStrong = score >= 0.7;
    final isMid = score >= 0.4;

    final String title;
    final String body;
    final Color color;
    final IconData icon;

    if (isStrong) {
      title = 'Excellent Performance';
      String styleTip = '';
      if (memory != null) {
        if (memory!.learningStyle.toLowerCase() == 'conceptual') {
          styleTip = ' Since they learn conceptually, provide high-level architecture designs or challenge them with underlying theory.';
        } else if (memory!.learningStyle.toLowerCase() == 'practice-based') {
          styleTip = ' Since they prefer practice, challenge them with mini-projects or open coding tasks.';
        }
      }
      body = 'This student is performing very well. Consider providing advanced supplementary material or more challenging questions to keep engagement high.$styleTip';
      color = AppColors.success;
      icon = Icons.emoji_events_rounded;
    } else if (isMid) {
      title = 'Needs Reinforcement';
      String weaknessTip = '';
      if (memory != null && memory!.weaknesses.isNotEmpty) {
        weaknessTip = ' Focus on reviewing: ${memory!.weaknesses.take(2).join(', ')}.';
      }
      body = 'This student shows moderate understanding. Focus on revisiting key concepts and increasing question frequency in weaker phases to build confidence.$weaknessTip';
      color = AppColors.warning;
      icon = Icons.trending_up;
    } else {
      title = 'Needs Additional Support';
      String paceTip = '';
      if (memory != null && memory!.preferredPace.toLowerCase() == 'slow') {
        paceTip = ' Since their preferred learning pace is slower, suggest breaking lessons down and reviewing confusion points one by one.';
      }
      body = 'This student is struggling. Consider simplifying questions, adding more detailed explanations in transcriptions, and encouraging repeated viewing of difficult sections.$paceTip';
      color = AppColors.error;
      icon = Icons.support_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Insight: $title',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textHigh,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textMed,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: 150.ms).fadeIn();
  }
}

class _CourseProgressCard extends StatelessWidget {
  final String courseName;
  final StudentCourseProgress lessonProgress;
  final List<LessonModel> lessons;

  const _CourseProgressCard({
    required this.courseName,
    required this.lessonProgress,
    required this.lessons,
  });

  @override
  Widget build(BuildContext context) {
    final completed = lessonProgress.lessonProgressMap.values
        .where((lp) => lp.isCompleted)
        .length;
    final total = lessons.length;
    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  courseName,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textHigh,
                  ),
                ),
              ),
              Text(
                '$completed / $total lessons',
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.textMed),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
          if (lessons.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...lessons.map((l) => _LessonDetailTile(
                  lesson: l,
                  progress: lessonProgress.lessonProgressMap[l.id],
                )),
          ],
        ],
      ),
    );
  }
}

class _LessonDetailTile extends StatefulWidget {
  final LessonModel lesson;
  final LessonProgress? progress;

  const _LessonDetailTile({
    required this.lesson,
    required this.progress,
  });

  @override
  State<_LessonDetailTile> createState() => _LessonDetailTileState();
}

class _LessonDetailTileState extends State<_LessonDetailTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final lp = widget.progress;
    final isDone = lp?.isCompleted ?? false;
    final score = lp?.overallScore ?? 0.0;
    final hasDetails = lp != null &&
        (lp.phaseResults.isNotEmpty ||
            lp.chatHistory.isNotEmpty ||
            lp.lookedAwayCount > 0);

    return Column(
      children: [
        InkWell(
          onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: isDone ? AppColors.success : AppColors.border,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.lesson.title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textHigh,
                    ),
                  ),
                ),
                if (isDone && lp != null && lp.totalQuestions > 0) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: score >= 0.7
                          ? AppColors.successLight
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${(score * 100).round()}%',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: score >= 0.7 ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (hasDetails)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.textLow,
                  ),
              ],
            ),
          ),
        ),
        if (_expanded && lp != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(left: 24, top: 4, bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Focus / Smart Pause stats
                if (lp.lookedAwayCount > 0) ...[
                  Row(
                    children: [
                      const Icon(Icons.visibility_off_outlined,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Text(
                        'Smart Pause Triggers: ${lp.lookedAwayCount} times',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textMed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // 2. Phase-by-phase quiz results
                if (widget.lesson.phases.isNotEmpty) ...[
                  Text(
                    'Quiz Phase Timeline:',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLow,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...widget.lesson.phases.map((phase) {
                    final phaseResult = lp.phaseResults
                        .where((r) => r.phaseId == phase.id)
                        .firstOrNull;
                    final phaseCompleted = phaseResult != null;
                    final phaseScore = phaseCompleted ? phaseResult.score : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            phaseCompleted
                                ? Icons.check_circle_outline
                                : Icons.pending_actions,
                            size: 13,
                            color: phaseCompleted
                                ? (phaseScore >= 0.7
                                    ? AppColors.success
                                    : AppColors.warning)
                                : AppColors.textLow,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              phase.title,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.textMed,
                              ),
                            ),
                          ),
                          if (phaseCompleted)
                            Text(
                              '${phaseResult.correct}/${phaseResult.total}',
                              style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: phaseScore >= 0.7
                                      ? AppColors.success
                                      : AppColors.warning),
                            )
                          else
                            Text(
                              'Not started',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.textLow,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],

                // 3. AI Tutor Chat History Log
                if (lp.chatHistory.isNotEmpty) ...[
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 6),
                  Text(
                    'AI Tutor Conversation:',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLow,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: lp.chatHistory.length,
                      itemBuilder: (context, index) {
                        final msg = lp.chatHistory[index];
                        final isUser = msg.role == 'user';
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          color: isUser
                              ? Colors.transparent
                              : AppColors.primaryLight.withValues(alpha: 0.1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUser ? 'Student:' : 'AI Tutor:',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isUser ? AppColors.textMed : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                msg.content,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.textHigh,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
