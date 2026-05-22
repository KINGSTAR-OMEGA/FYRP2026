import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import 'admin/admin_shell.dart';
import 'student/student_shell.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _loading = false;
  String? _selectedRole; // 'student' or 'admin' (representing teacher)

  @override
  void initState() {
    super.initState();
    // Auto-redirect if already logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        _navigateToHome(auth.isAdmin);
      }
    });
  }

  void _navigateToHome(bool isAdmin) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => isAdmin ? const AdminShell() : const StudentShell(),
      ),
      (route) => false,
    );
  }

  Future<void> _signIn({required String role, bool simulate = false, String? email}) async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.signInWithGoogle(
        selectedRole: role,
        simulate: simulate,
        simulateEmail: email,
      );
      if (!mounted) return;

      if (auth.isLoggedIn) {
        _navigateToHome(auth.isAdmin);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'Bypass / Simulate',
            textColor: Colors.white,
            onPressed: () => _showSimulationDialog(preSelectedRole: role),
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSimulationDialog({String? preSelectedRole}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          'Simulate Google Account',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Google Sign-In is active. If your SHA-1 keys aren\'t registered in the Firebase console yet, you can simulate a successful sign-in with a test account:',
          style: GoogleFonts.outfit(color: AppColors.textMed),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _signIn(role: preSelectedRole ?? 'student', simulate: true, email: 'rashmi@eduai.com');
            },
            child: Text(
              'Simulate Student (Rashmi)',
              style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _signIn(role: preSelectedRole ?? 'admin', simulate: true, email: 'admin@eduai.com');
            },
            child: Text(
              'Simulate Admin (Admin)',
              style: GoogleFonts.outfit(color: AppColors.secondary, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textLow),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo Mark
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                  )
                      .animate()
                      .scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut)
                      .fadeIn(duration: 500.ms),
                  const SizedBox(height: 24),

                  Text(
                    'Welcome to EduAI',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textHigh,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 6),
                  Text(
                    'Choose your profile role to continue',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textMed,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 36),

                  // Role Selection Cards
                  Row(
                    children: [
                      Expanded(
                        child: _RoleSelectCard(
                          title: 'Student',
                          subtitle: 'Learn & track your course progress',
                          icon: Icons.school_rounded,
                          color: AppColors.primary,
                          selected: _selectedRole == 'student',
                          onTap: () => setState(() => _selectedRole = 'student'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _RoleSelectCard(
                          title: 'Teacher',
                          subtitle: 'Manage courses & view analytics',
                          icon: Icons.manage_accounts_rounded,
                          color: AppColors.secondary,
                          selected: _selectedRole == 'admin',
                          onTap: () => setState(() => _selectedRole = 'admin'),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15, end: 0),

                  const SizedBox(height: 40),

                  // Google Login Button (Visible when a role is selected)
                  AnimatedOpacity(
                    opacity: _selectedRole != null ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_loading || _selectedRole == null)
                            ? null
                            : () => _signIn(role: _selectedRole!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: _selectedRole != null ? 1 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: _selectedRole != null
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                                    width: 20,
                                    height: 20,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.g_mobiledata, color: Colors.blue, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _selectedRole == null
                                        ? 'Select role to sign in'
                                        : _selectedRole == 'student'
                                            ? 'Sign in as Student'
                                            : 'Sign in as Teacher',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedRole != null ? Colors.black87 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),
                  // Dynamic status text / bypass link
                  GestureDetector(
                    onTap: () => _showSimulationDialog(preSelectedRole: _selectedRole),
                    child: Text(
                      'Demo/Bypass Simulation Mode',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textLow,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSelectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RoleSelectCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.05) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textHigh,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textMed,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
