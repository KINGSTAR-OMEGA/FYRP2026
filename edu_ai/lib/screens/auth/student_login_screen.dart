import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';
import '../../utils/theme.dart';
import '../student/student_shell.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  UserModel? _selected;
  bool _loading = false;

  Future<void> _login() async {
    if (_selected == null) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    context.read<AuthProvider>().loginAsStudent(_selected!);
    await context.read<ProgressProvider>().loadProgress();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StudentShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: AppColors.primary, size: 24),
                ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: 20),
                Text(
                  'Student Login',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHigh,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
                const SizedBox(height: 6),
                Text(
                  'Select your account to continue learning',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.textMed),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 32),
                ...List.generate(
                  demoStudents.length,
                  (i) => _StudentTile(
                    student: demoStudents[i],
                    selected: _selected?.id == demoStudents[i].id,
                    onTap: () =>
                        setState(() => _selected = demoStudents[i]),
                  ).animate(delay: Duration(milliseconds: 200 + i * 80))
                      .fadeIn()
                      .slideX(begin: 0.1),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_selected == null || _loading) ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white)),
                          )
                        : const Text('Continue as Student'),
                  ),
                ).animate(delay: 500.ms).fadeIn(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}

class _StudentTile extends StatelessWidget {
  final UserModel student;
  final bool selected;
  final VoidCallback onTap;

  const _StudentTile({
    required this.student,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  selected ? AppColors.primary : AppColors.border,
              child: Text(
                student.initials,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textMed,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textHigh,
                    ),
                  ),
                  Text(
                    student.email,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.textLow),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
