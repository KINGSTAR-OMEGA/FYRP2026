import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../providers/course_provider.dart';
import '../../utils/theme.dart';
import 'admin_create_course_screen.dart';
import 'admin_lesson_editor_screen.dart';

class AdminCoursesScreen extends StatelessWidget {
  const AdminCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseProvider>().courses;
    final isLoading = context.watch<CourseProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminCreateCourseScreen()),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Course'),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : courses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.video_library_outlined,
                            size: 32, color: AppColors.textLow),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No courses yet',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHigh,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first course to get started',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: AppColors.textMed),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminCreateCourseScreen()),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Course'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: courses.length,
                  itemBuilder: (context, i) => _CourseCard(
                    course: courses[i],
                    index: i,
                  ).animate(delay: Duration(milliseconds: i * 60))
                      .fadeIn()
                      .slideY(begin: 0.1),
                ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final int index;

  const _CourseCard({required this.course, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textHigh,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Chip(
                            label: course.category,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          _Chip(
                            label: '${course.totalLessons} lessons',
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => _handleAction(context, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  child: const Icon(Icons.more_vert, color: AppColors.textLow),
                ),
              ],
            ),
          ),
          if (course.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Text(
                course.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 13, color: AppColors.textMed, height: 1.4),
              ),
            ),
          const Divider(height: 1),
          // Lessons list
          if (course.lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppColors.textLow),
                  const SizedBox(width: 6),
                  Text(
                    'No lessons yet',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.textLow),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _addLesson(context),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Lesson'),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        textStyle: GoogleFonts.outfit(fontSize: 12)),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                ...course.lessons.map((l) => _LessonRow(
                      lesson: l,
                      courseId: course.id,
                    )),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton.icon(
                    onPressed: () => _addLesson(context),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Lesson'),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        textStyle: GoogleFonts.outfit(fontSize: 12)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _addLesson(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AdminLessonEditorScreen(
              courseId: course.id, lessonOrder: course.totalLessons)),
    );
  }

  void _handleAction(BuildContext context, String action) {
    if (action == 'delete') {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Course'),
          content: Text('Delete "${course.title}"? This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                context.read<CourseProvider>().deleteCourse(course.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    }
  }
}

class _LessonRow extends StatelessWidget {
  final dynamic lesson;
  final String courseId;

  const _LessonRow({required this.lesson, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AdminLessonEditorScreen(
                courseId: courseId,
                existingLesson: lesson,
                lessonOrder: lesson.order)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  '${lesson.order + 1}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMed,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.play_circle_outline,
                size: 16, color: AppColors.textLow),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lesson.title,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textHigh,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '${lesson.phases.length} phases',
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLow),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined,
                size: 14, color: AppColors.textLow),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
