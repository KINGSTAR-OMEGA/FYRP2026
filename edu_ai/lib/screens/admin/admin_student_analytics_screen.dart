import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/course_provider.dart';
import '../../providers/progress_provider.dart';
import '../../utils/theme.dart';

class AdminStudentAnalyticsScreen extends StatefulWidget {
  const AdminStudentAnalyticsScreen({super.key});

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
    _selected = demoStudents.first;
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final courses = context.watch<CourseProvider>().courses;

    final studentProgress = _selected != null
        ? progress.getAllProgressForStudent(_selected!.id)
        : [];
    final completedLessons = _selected != null
        ? progress.getCompletedLessonsCount(_selected!.id)
        : 0;
    final overallScore = _selected != null
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
                      children: demoStudents.map((s) {
                        final selected = _selected?.id == s.id;
                        return GestureDetector(
                          onTap: () => setState(() => _selected = s),
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
                          courses: courses,
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
                    ...demoStudents.map(
                      (s) => _StudentListTile(
                        student: s,
                        selected: _selected?.id == s.id,
                        score: progress.getStudentOverallScore(s.id),
                        onTap: () => setState(() => _selected = s),
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
                        courses: courses,
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
  final List studentProgress;
  final List courses;

  const _StudentDetailPanel({
    required this.student,
    required this.completedLessons,
    required this.overallScore,
    required this.studentProgress,
    required this.courses,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (overallScore * 100).round();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHigh,
                        ),
                      ),
                      Text(
                        student.email,
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: AppColors.textMed),
                      ),
                    ],
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

              // Performance suggestion
              if (overallScore > 0) ...[
                _SuggestionCard(score: overallScore),
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
                  final course = courses
                      .cast<dynamic>()
                      .where((c) => c.id == cp.courseId)
                      .firstOrNull;
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
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final double score;

  const _SuggestionCard({required this.score});

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
      body = 'This student is performing very well. Consider providing advanced supplementary material or more challenging questions to keep engagement high.';
      color = AppColors.success;
      icon = Icons.emoji_events_rounded;
    } else if (isMid) {
      title = 'Needs Reinforcement';
      body = 'This student shows moderate understanding. Focus on revisiting key concepts and increasing question frequency in weaker phases to build confidence.';
      color = AppColors.warning;
      icon = Icons.trending_up;
    } else {
      title = 'Needs Additional Support';
      body = 'This student is struggling. Consider simplifying questions, adding more detailed explanations in transcriptions, and encouraging repeated viewing of difficult sections.';
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
  final dynamic lessonProgress;
  final List lessons;

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
            ...lessons.map((l) {
              final lp = lessonProgress.lessonProgressMap[l.id];
              final isDone = lp?.isCompleted ?? false;
              final score = lp?.overallScore ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 14,
                      color: isDone ? AppColors.success : AppColors.border,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.title,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.textMed),
                      ),
                    ),
                    if (isDone && lp!.totalQuestions > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
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
                            color: score >= 0.7
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
