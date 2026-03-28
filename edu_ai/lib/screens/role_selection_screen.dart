import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';
import 'auth/admin_login_screen.dart';
import 'auth/student_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(height: 20),
                Text(
                  'Welcome to EduAI',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHigh,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you\'d like to continue',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: AppColors.textMed,
                  ),
                ),
                const SizedBox(height: 48),

                // Role cards
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        title: 'Student',
                        subtitle: 'Learn, watch lessons,\nand grow your skills',
                        icon: Icons.school_rounded,
                        color: AppColors.primary,
                        delay: 0,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StudentLoginScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleCard(
                        title: 'Admin',
                        subtitle: 'Manage courses,\nupload lessons & track students',
                        icon: Icons.manage_accounts_rounded,
                        color: AppColors.secondary,
                        delay: 100,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminLoginScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Demo mode — no real accounts needed',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textLow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int delay;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withValues(alpha: 0.04) : AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? widget.color.withValues(alpha: 0.5) : AppColors.border,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHigh,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textMed,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Continue',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: widget.color, size: 14),
                ],
              ),
            ],
          ),
        ).animate(delay: Duration(milliseconds: widget.delay))
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.2, end: 0),
      ),
    );
  }
}
