import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/progress_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/common/stat_card.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final courses = context.watch<CourseProvider>().courses;
    final progress = context.watch<ProgressProvider>();

    final totalLessons = courses.fold(0, (s, c) => s + c.totalLessons);
    final completedLessons = demoStudents.fold(
        0, (s, st) => s + progress.getCompletedLessonsCount(st.id));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.bg,
            title: Text(
              'Dashboard',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700, color: AppColors.textHigh),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.secondaryLight,
                  child: Text(
                    user.initials,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
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
                // Greeting
                Text(
                  'Good day, ${user.name.split(' ').first}!',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHigh,
                  ),
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 4),
                Text(
                  'Here\'s an overview of your platform today.',
                  style:
                      GoogleFonts.outfit(fontSize: 14, color: AppColors.textMed),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 28),

                // Stats grid
                LayoutBuilder(builder: (context, constraints) {
                  final cols = constraints.maxWidth > 600 ? 4 : 2;
                  return _StatsGrid(
                    courses: courses.length,
                    lessons: totalLessons,
                    students: demoStudents.length,
                    completed: completedLessons,
                    cols: cols,
                  );
                }),
                const SizedBox(height: 32),

                // Recent courses
                Row(
                  children: [
                    Text(
                      'Recent Courses',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHigh,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text('View all'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (courses.isEmpty)
                  _EmptyState(
                    icon: Icons.video_library_outlined,
                    title: 'No courses yet',
                    subtitle: 'Go to the Courses tab to create your first course.',
                  )
                else
                  ...courses.take(3).map((c) => _CourseSummaryTile(course: c)),

                const SizedBox(height: 32),

                // Student overview
                Text(
                  'Student Overview',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHigh,
                  ),
                ),
                const SizedBox(height: 12),
                ...demoStudents.map((s) => _StudentOverviewTile(
                      student: s,
                      completedLessons: progress.getCompletedLessonsCount(s.id),
                      overallScore: progress.getStudentOverallScore(s.id),
                    )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int courses;
  final int lessons;
  final int students;
  final int completed;
  final int cols;

  const _StatsGrid({
    required this.courses,
    required this.lessons,
    required this.students,
    required this.completed,
    required this.cols,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      StatCard(
        label: 'Total Courses',
        value: '$courses',
        icon: Icons.video_library,
        color: AppColors.primary,
      ),
      StatCard(
        label: 'Total Lessons',
        value: '$lessons',
        icon: Icons.play_circle_outline,
        color: AppColors.secondary,
      ),
      StatCard(
        label: 'Students',
        value: '$students',
        icon: Icons.people,
        color: AppColors.accent,
      ),
      StatCard(
        label: 'Lessons Completed',
        value: '$completed',
        icon: Icons.check_circle_outline,
        color: AppColors.success,
      ),
    ];

    if (cols == 4) {
      return Row(
        children: cards
            .asMap()
            .entries
            .map((e) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: e.key < cards.length - 1 ? 12 : 0),
                    child: e.value.animate(delay: Duration(milliseconds: e.key * 80)).fadeIn().slideY(begin: 0.2),
                  ),
                ))
            .toList(),
      );
    }

    return GridView.count(
      crossAxisCount: cols,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards
          .asMap()
          .entries
          .map((e) => e.value
              .animate(delay: Duration(milliseconds: e.key * 80))
              .fadeIn()
              .slideY(begin: 0.2))
          .toList(),
    );
  }
}

class _CourseSummaryTile extends StatelessWidget {
  final dynamic course;

  const _CourseSummaryTile({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_circle_outline,
                color: AppColors.primary, size: 20),
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
                      color: AppColors.textHigh),
                ),
                Text(
                  '${course.totalLessons} lessons  •  ${course.category}',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.textLow),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              size: 14, color: AppColors.textLow),
        ],
      ),
    );
  }
}

class _StudentOverviewTile extends StatelessWidget {
  final dynamic student;
  final int completedLessons;
  final double overallScore;

  const _StudentOverviewTile({
    required this.student,
    required this.completedLessons,
    required this.overallScore,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (overallScore * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              student.initials,
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textHigh),
                ),
                Text(
                  '$completedLessons lessons completed',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.textLow),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pct >= 70
                  ? AppColors.successLight
                  : pct >= 40
                      ? AppColors.warningLight
                      : AppColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              overallScore == 0 ? 'No data' : '$pct%',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: pct >= 70
                    ? AppColors.success
                    : pct >= 40
                        ? AppColors.warning
                        : AppColors.textLow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textLow),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.textMed),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLow),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
