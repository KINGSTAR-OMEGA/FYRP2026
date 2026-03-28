import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/progress_provider.dart';
import '../../utils/theme.dart';
import 'student_course_detail_screen.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final courses = context.watch<CourseProvider>().courses;
    final progress = context.watch<ProgressProvider>();

    final completed = progress.getCompletedLessonsCount(user.id);
    final score = progress.getStudentOverallScore(user.id);

    // Find in-progress course
    final inProgress = courses.where((c) {
      final cp = progress.getProgress(user.id, c.id);
      return cp.lessonProgressMap.isNotEmpty &&
          cp.lessonProgressMap.values.any((l) => l.watchedSeconds > 0) &&
          !cp.lessonProgressMap.values.every((l) => l.isCompleted);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.bg,
            title: Text(
              'Home',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700, color: AppColors.textHigh),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    user.initials,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Greeting banner
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, ${user.name.split(' ').first}!',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ready to continue learning?',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                _StatPill(
                                  label: '$completed',
                                  sublabel: 'Lessons done',
                                ),
                                _StatPill(
                                  label: score == 0
                                      ? '—'
                                      : '${(score * 100).round()}%',
                                  sublabel: 'Avg score',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Hide icon on very small screens to save space
                      LayoutBuilder(builder: (ctx, c) {
                        if (c.maxWidth < 80) return const SizedBox.shrink();
                        return const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 52,
                          ),
                        );
                      }),
                    ],
                  ),
                ).animate().fadeIn().scale(begin: const Offset(0.97, 0.97)),
                const SizedBox(height: 28),

                // Continue learning
                if (inProgress.isNotEmpty) ...[
                  Text(
                    'Continue Learning',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHigh,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 12),
                  ...inProgress.take(2).map(
                        (c) => _ContinueCourseCard(course: c, studentId: user.id)
                            .animate(delay: 150.ms)
                            .fadeIn()
                            .slideY(begin: 0.1),
                      ),
                  const SizedBox(height: 24),
                ],

                // All courses
                Row(
                  children: [
                    Text(
                      'All Courses',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHigh,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${courses.length} available',
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: AppColors.textLow),
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 12),
                if (courses.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.school_outlined,
                            size: 40, color: AppColors.textLow),
                        const SizedBox(height: 12),
                        Text(
                          'No courses available yet',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ask your admin to upload course content.',
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.textLow),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 250.ms)
                else
                  ...courses.asMap().entries.map(
                        (e) => _CourseListCard(
                          course: e.value,
                          studentId: user.id,
                          progress: progress,
                        )
                            .animate(
                                delay: Duration(
                                    milliseconds: 250 + e.key * 60))
                            .fadeIn()
                            .slideY(begin: 0.1),
                      ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String sublabel;

  const _StatPill({required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18),
          ),
          Text(
            sublabel,
            style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ContinueCourseCard extends StatelessWidget {
  final dynamic course;
  final String studentId;

  const _ContinueCourseCard({required this.course, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => StudentCourseDetailScreen(course: course)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textHigh,
                    ),
                  ),
                  Text(
                    'Continue where you left off',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _CourseListCard extends StatelessWidget {
  final dynamic course;
  final String studentId;
  final ProgressProvider progress;

  const _CourseListCard({
    required this.course,
    required this.studentId,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final cp = progress.getProgress(studentId, course.id);
    final completed =
        cp.lessonProgressMap.values.where((l) => l.isCompleted).length;
    final total = course.totalLessons;
    final pct = total == 0 ? 0.0 : completed / total;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => StudentCourseDetailScreen(course: course)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.video_library_outlined,
                  color: AppColors.textMed, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$completed/$total lessons',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.textMed),
                      ),
                      if (total > 0) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                              minHeight: 4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textLow),
          ],
        ),
      ),
    );
  }
}
