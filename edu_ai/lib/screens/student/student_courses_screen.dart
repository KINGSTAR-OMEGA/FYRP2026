import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/progress_provider.dart';
import '../../utils/theme.dart';
import 'student_course_detail_screen.dart';

class StudentCoursesScreen extends StatelessWidget {
  const StudentCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final courses = context.watch<CourseProvider>().courses;
    final progress = context.watch<ProgressProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Courses'),
      ),
      body: courses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school_outlined,
                      size: 56, color: AppColors.textLow),
                  const SizedBox(height: 16),
                  Text(
                    'No courses available',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMed,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your instructor hasn\'t uploaded any courses yet.',
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: AppColors.textLow),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: courses.length,
              itemBuilder: (context, i) {
                final course = courses[i];
                final cp = progress.getProgress(user.id, course.id);
                final completed = cp.lessonProgressMap.values
                    .where((l) => l.isCompleted)
                    .length;
                final total = course.totalLessons;
                final pct = total == 0 ? 0.0 : completed / total;

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            StudentCourseDetailScreen(course: course)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with gradient strip
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      course.category,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (pct == 1.0 && total > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.successLight,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle,
                                              size: 12,
                                              color: AppColors.success),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Completed',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                course.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textHigh,
                                ),
                              ),
                              if (course.description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  course.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppColors.textMed,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.play_circle_outline,
                                      size: 16, color: AppColors.textLow),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$total lessons',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppColors.textMed),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$completed/$total',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMed,
                                    ),
                                  ),
                                ],
                              ),
                              if (total > 0) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor: AppColors.border,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            AppColors.primary),
                                    minHeight: 5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate(
                          delay: Duration(milliseconds: i * 70))
                      .fadeIn()
                      .slideY(begin: 0.1),
                );
              },
            ),
    );
  }
}
