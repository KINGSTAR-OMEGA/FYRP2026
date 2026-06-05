import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/progress_provider.dart';
import '../../utils/theme.dart';
import 'admin_courses_screen.dart';
import 'admin_student_analytics_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final courses = context.watch<CourseProvider>().courses;
    final progress = context.watch<ProgressProvider>();
    final students = context.watch<AuthProvider>().students;

    final totalLessons = courses.fold(0, (s, c) => s + c.totalLessons);
    final completedLessons = students.fold(
        0, (s, st) => s + progress.getCompletedLessonsCount(st.id));
    final avgScore = students.isEmpty
        ? 0.0
        : students.fold(0.0,
                (s, st) => s + progress.getStudentOverallScore(st.id)) /
            students.length;

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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Greeting
                Text(
                  'Good day, ${user.name.split(' ').first}!',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHigh,
                  ),
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 2),
                Text(
                  'Here\'s an overview of your platform.',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: AppColors.textMed),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: 16),

                // ── Stats grid (always 2 cols on mobile) ─────────────────
                _CompactStatsGrid(
                  courses: courses.length,
                  lessons: totalLessons,
                  students: students.length,
                  avgScore: avgScore,
                  completed: completedLessons,
                ),
                const SizedBox(height: 20),

                // ── Recent courses ────────────────────────────────────────
                _SectionHeader(
                  title: 'Recent Courses',
                  actionLabel: 'View all',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminCoursesScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                if (courses.isEmpty)
                  _EmptyState(
                    icon: Icons.video_library_outlined,
                    title: 'No courses yet',
                    subtitle:
                        'Go to the Courses tab to create your first course.',
                  )
                else
                  ...courses
                      .take(3)
                      .map((c) => _CourseSummaryTile(course: c)),

                const SizedBox(height: 20),

                // ── Student overview ──────────────────────────────────────
                _SectionHeader(
                  title: 'Students',
                  actionLabel: 'Analytics',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const AdminStudentAnalyticsScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                ...students.map((s) => _StudentOverviewTile(
                      student: s,
                      completedLessons:
                          progress.getCompletedLessonsCount(s.id),
                      overallScore: progress.getStudentOverallScore(s.id),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                AdminStudentAnalyticsScreen(initialStudent: s)),
                      ),
                    )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header with action ────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textHigh,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onAction,
          child: Row(
            children: [
              Text(
                actionLabel,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_forward_ios,
                  size: 11, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Compact stats grid (2×2 on mobile, 4×1 on wide) ──────────────────────────
class _CompactStatsGrid extends StatelessWidget {
  final int courses;
  final int lessons;
  final int students;
  final int completed;
  final double avgScore;

  const _CompactStatsGrid({
    required this.courses,
    required this.lessons,
    required this.students,
    required this.completed,
    required this.avgScore,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(                    
        label: 'Courses',
        value: '$courses',
        icon: Icons.video_library_rounded,
        color: AppColors.primary,
      ),
      _StatItem(
        label: 'Lessons',
        value: '$lessons',
        icon: Icons.play_circle_rounded,
        color: AppColors.secondary,
      ),
      _StatItem(
        label: 'Students',
        value: '$students',
        icon: Icons.people_rounded,
        color: AppColors.accent,
      ),
      _StatItem(
        label: 'Avg Score',
        value: avgScore == 0 ? '—' : '${(avgScore * 100).round()}%',
        icon: Icons.star_rounded,
        color: AppColors.success,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 600;
      if (isWide) {
        return Row(
          children: items
              .asMap()
              .entries
              .map((e) => Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.only(right: e.key < items.length - 1 ? 10 : 0),
                      child: e.value
                          .animate(
                              delay: Duration(milliseconds: e.key * 70))
                          .fadeIn()
                          .slideY(begin: 0.2),
                    ),
                  ))
              .toList(),
        );
      }
      // 2-column grid
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: items
            .asMap()
            .entries
            .map((e) => e.value
                .animate(delay: Duration(milliseconds: e.key * 70))
                .fadeIn()
                .slideY(begin: 0.2))
            .toList(),
      );
    });
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHigh,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textMed,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Course summary tile ───────────────────────────────────────────────────────
class _CourseSummaryTile extends StatelessWidget {
  final dynamic course;

  const _CourseSummaryTile({required this.course});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminCoursesScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.play_circle_outline,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textHigh),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${course.totalLessons} lessons  •  ${course.category}',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.textLow),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 12, color: AppColors.textLow),
          ],
        ),
      ),
    );
  }
}

// ── Student overview tile ─────────────────────────────────────────────────────
class _StudentOverviewTile extends StatelessWidget {
  final dynamic student;
  final int completedLessons;
  final double overallScore;
  final VoidCallback onTap;

  const _StudentOverviewTile({
    required this.student,
    required this.completedLessons,
    required this.overallScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (overallScore * 100).round();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                student.initials,
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 11),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textHigh),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$completedLessons lessons completed',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.textLow),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: pct >= 70
                    ? AppColors.successLight
                    : pct >= 40
                        ? AppColors.warningLight
                        : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: pct >= 70
                      ? AppColors.success.withValues(alpha: 0.3)
                      : pct >= 40
                          ? AppColors.warning.withValues(alpha: 0.3)
                          : AppColors.border,
                ),
              ),
              child: Text(
                overallScore == 0 ? 'No data' : '$pct%',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: pct >= 70
                      ? AppColors.success
                      : pct >= 40
                          ? AppColors.warning
                          : AppColors.textLow,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios,
                size: 12, color: AppColors.textLow),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textLow),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textMed),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLow),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
