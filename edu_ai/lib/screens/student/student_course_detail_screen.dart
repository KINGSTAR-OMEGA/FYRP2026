import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../models/lesson_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';
import '../../utils/theme.dart';
import 'video_learning_screen.dart';

class StudentCourseDetailScreen extends StatelessWidget {
  final CourseModel course;

  const StudentCourseDetailScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final progress = context.watch<ProgressProvider>();

    final orderedLessons = List<LessonModel>.from(course.lessons)
      ..sort((a, b) => a.order.compareTo(b.order));
    final lessonIds = orderedLessons.map((l) => l.id).toList();

    final completedCount = orderedLessons
        .where((l) => progress.isLessonCompleted(user.id, course.id, l.id))
        .length;
    final pct = orderedLessons.isEmpty
        ? 0.0
        : completedCount / orderedLessons.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Custom header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.bg,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            course.category,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          course.title,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
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

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$completedCount / ${orderedLessons.length} lessons',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textHigh,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${(pct * 100).round()}%',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(),
                const SizedBox(height: 8),
                if (course.description.isNotEmpty) ...[
                  Text(
                    course.description,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textMed,
                        height: 1.5),
                  ).animate().fadeIn(delay: 50.ms),
                  const SizedBox(height: 20),
                ],

                Text(
                  'Lessons',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHigh,
                  ),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: 12),

                if (orderedLessons.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        'No lessons uploaded yet.',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: AppColors.textLow),
                      ),
                    ),
                  )
                else
                  ...orderedLessons.asMap().entries.map((e) {
                    final lesson = e.value;
                    final idx = e.key;
                    final isCompleted =
                        progress.isLessonCompleted(user.id, course.id, lesson.id);
                    final isUnlocked = progress.isLessonUnlocked(
                        user.id, course.id, lessonIds, lesson.id);
                    final lp = progress.getLessonProgress(
                        user.id, course.id, lesson.id);

                    return _LessonCard(
                      lesson: lesson,
                      index: idx,
                      isCompleted: isCompleted,
                      isUnlocked: isUnlocked,
                      watchedSeconds: lp.watchedSeconds,
                      onTap: isUnlocked
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoLearningScreen(
                                    course: course,
                                    lesson: lesson,
                                  ),
                                ),
                              )
                          : null,
                    ).animate(
                        delay: Duration(milliseconds: 100 + idx * 60)).fadeIn().slideY(begin: 0.1);
                  }),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final dynamic lesson;
  final int index;
  final bool isCompleted;
  final bool isUnlocked;
  final double watchedSeconds;
  final VoidCallback? onTap;

  const _LessonCard({
    required this.lesson,
    required this.index,
    required this.isCompleted,
    required this.isUnlocked,
    required this.watchedSeconds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isUnlocked ? 1.0 : 0.5,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.successLight
                : isUnlocked
                    ? AppColors.bgCard
                    : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompleted
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.success
                      : isUnlocked
                          ? AppColors.primary
                          : AppColors.textLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_rounded
                      : isUnlocked
                          ? Icons.play_arrow_rounded
                          : Icons.lock_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lesson ${index + 1}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textLow,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      lesson.title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHigh,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    // Use Wrap so badges never overflow on narrow screens
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.segment,
                                size: 12, color: AppColors.textLow),
                            const SizedBox(width: 4),
                            Text(
                              '${lesson.phases.length} phases',
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: AppColors.textLow),
                            ),
                          ],
                        ),
                        if (!isUnlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'Finish previous first',
                              style: GoogleFonts.outfit(
                                  fontSize: 10, color: AppColors.textLow),
                            ),
                          ),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Completed',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isUnlocked && !isCompleted && watchedSeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Resume',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              if (isUnlocked)
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppColors.textLow),
            ],
          ),
        ),
      ),
    );
  }
}
