import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../utils/theme.dart';
import '../role_selection_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_courses_screen.dart';
import 'admin_student_analytics_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  final _screens = const [
    AdminDashboardScreen(),
    AdminCoursesScreen(),
    AdminStudentAnalyticsScreen(),
  ];

  final _navItems = const [
    (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    (icon: Icons.video_library_outlined, activeIcon: Icons.video_library, label: 'Courses'),
    (icon: Icons.people_outlined, activeIcon: Icons.people, label: 'Students'),
  ];

  @override
  void initState() {
    super.initState();
    context.read<CourseProvider>().loadCourses();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final isWide = MediaQuery.of(context).size.width > 900;

    if (isWide) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Row(
          children: [
            _SideNav(
              index: _index,
              items: _navItems,
              onTap: (i) => setState(() => _index = i),
              user: user,
              onLogout: _logout,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _screens[_index]),
          ],
        ),
      );
    }

    // Mobile: bottom nav + profile sheet
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i == _navItems.length) {
            _showProfileSheet(context, user);
          } else {
            setState(() => _index = i);
          }
        },
        backgroundColor: AppColors.bg,
        indicatorColor: AppColors.primaryLight,
        destinations: [
          ..._navItems.map((item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.activeIcon, color: AppColors.primary),
                label: item.label,
              )),
          NavigationDestination(
            icon: CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.secondaryLight,
              child: Text(
                user.initials,
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary),
              ),
            ),
            selectedIcon: CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.secondary,
              child: Text(
                user.initials,
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(BuildContext context, dynamic user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProfileSheet(
        user: user,
        role: 'Admin',
        accentColor: AppColors.secondary,
        accentLight: AppColors.secondaryLight,
        onLogout: _logout,
      ),
    );
  }

  void _logout() {
    Navigator.of(context).pop(); // close sheet if open
    context.read<AuthProvider>().logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }
}

class _SideNav extends StatelessWidget {
  final int index;
  final List<({IconData icon, IconData activeIcon, String label})> items;
  final ValueChanged<int> onTap;
  final dynamic user;
  final VoidCallback onLogout;

  const _SideNav({
    required this.index,
    required this.items,
    required this.onTap,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'EduAI',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHigh,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(
            items.length,
            (i) => _NavItem(
              icon: index == i ? items[i].activeIcon : items[i].icon,
              label: items[i].label,
              selected: index == i,
              onTap: () => onTap(i),
            ),
          ),
          const Spacer(),
          const Divider(indent: 20, endIndent: 20),
          _UserTile(user: user, onLogout: onLogout),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primaryLight
                : _hovered
                    ? AppColors.bgSurface
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.selected ? AppColors.primary : AppColors.textMed,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                  color: widget.selected ? AppColors.primary : AppColors.textMed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final dynamic user;
  final VoidCallback onLogout;

  const _UserTile({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.secondaryLight,
            child: Text(
              user.initials,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHigh,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Admin',
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: AppColors.textLow),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 18),
            color: AppColors.textLow,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}

// ── Shared profile bottom sheet ───────────────────────────────────────────────
class _ProfileSheet extends StatelessWidget {
  final dynamic user;
  final String role;
  final Color accentColor;
  final Color accentLight;
  final VoidCallback onLogout;

  const _ProfileSheet({
    required this.user,
    required this.role,
    required this.accentColor,
    required this.accentLight,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Avatar
          CircleAvatar(
            radius: 38,
            backgroundColor: accentLight,
            child: Text(
              user.initials,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Name
          Text(
            user.name,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textHigh,
            ),
          ),
          const SizedBox(height: 6),

          // Role badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: accentLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Email
          Text(
            user.email,
            style: GoogleFonts.outfit(
                fontSize: 13, color: AppColors.textLow),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded,
                  color: AppColors.error, size: 18),
              label: Text(
                'Logout',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
