import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/course_model.dart';
import '../../providers/course_provider.dart';
import '../../utils/theme.dart';

class AdminCreateCourseScreen extends StatefulWidget {
  const AdminCreateCourseScreen({super.key});

  @override
  State<AdminCreateCourseScreen> createState() =>
      _AdminCreateCourseScreenState();
}

class _AdminCreateCourseScreenState extends State<AdminCreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'General';
  bool _saving = false;

  final _categories = [
    'General',
    'Mathematics',
    'Science',
    'Programming',
    'Language',
    'History',
    'Arts',
    'Business',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final course = CourseModel(
      id: const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      lessons: [],
      createdAt: DateTime.now(),
    );

    await context.read<CourseProvider>().addCourse(course);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('New Course'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Text('Create'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Course Details',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHigh,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 4),
                Text(
                  'Fill in the basic information for your new course.',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: AppColors.textMed),
                ).animate().fadeIn(delay: 50.ms),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Course Title *',
                    hintText: 'e.g. Introduction to Calculus',
                    prefixIcon: Icon(Icons.title, size: 20),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Title is required' : null,
                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What will students learn in this course?',
                    prefixIcon: Icon(Icons.description_outlined, size: 20),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.2),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined, size: 20),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'After creating the course, you can add video lessons with transcriptions and phases.',
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 250.ms).fadeIn(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
