import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/lesson_model.dart';
import '../../models/phase_model.dart';
import '../../providers/course_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/admin/phase_editor_widget.dart';

class AdminLessonEditorScreen extends StatefulWidget {
  final String courseId;
  final LessonModel? existingLesson;
  final int lessonOrder;

  const AdminLessonEditorScreen({
    super.key,
    required this.courseId,
    this.existingLesson,
    required this.lessonOrder,
  });

  @override
  State<AdminLessonEditorScreen> createState() =>
      _AdminLessonEditorScreenState();
}

class _AdminLessonEditorScreenState extends State<AdminLessonEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _transcriptCtrl;
  String _videoPath = '';
  late List<PhaseModel> _phases;
  bool _saving = false;   // save-to-provider spinner
  bool _copying = false;  // video copy-to-storage spinner

  @override
  void initState() {
    super.initState();
    final l = widget.existingLesson;
    _titleCtrl = TextEditingController(text: l?.title ?? '');
    _transcriptCtrl = TextEditingController(text: l?.transcription ?? '');
    _videoPath = l?.videoPath ?? '';
    _phases = l?.phases != null ? List.from(l!.phases) : [];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _transcriptCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null) return;

    final picked = result.files.single;
    final sourcePath = picked.path;
    if (sourcePath == null) return;

    setState(() => _copying = true);

    try {
      // Copy to app documents so the path survives across sessions
      final docsDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${docsDir.path}/edu_videos');
      if (!videosDir.existsSync()) videosDir.createSync(recursive: true);

      final destPath = '${videosDir.path}/${picked.name}';
      await File(sourcePath).copy(destPath);

      setState(() {
        _videoPath = destPath;
        _copying = false;
      });
    } catch (_) {
      // Fallback: use the original path (works within the same session)
      setState(() {
        _videoPath = sourcePath;
        _copying = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final lesson = LessonModel(
      id: widget.existingLesson?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      videoPath: _videoPath,
      transcription: _transcriptCtrl.text.trim(),
      phases: _phases,
      order: widget.lessonOrder,
    );

    final provider = context.read<CourseProvider>();
    if (widget.existingLesson != null) {
      await provider.updateLesson(widget.courseId, lesson);
    } else {
      await provider.addLessonToCourse(widget.courseId, lesson);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingLesson != null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Lesson' : 'Add Lesson'),
        actions: [
          if (isEdit)
            TextButton(
              onPressed: () => _confirmDelete(context),
              child: Text(
                'Delete',
                style: GoogleFonts.outfit(color: AppColors.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: (_saving || _copying) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : Text(isEdit ? 'Save Changes' : 'Add Lesson'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lesson Title *',
                    hintText: 'e.g. Introduction to Variables',
                    prefixIcon: Icon(Icons.text_fields, size: 20),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ).animate().fadeIn().slideY(begin: 0.1),
                const SizedBox(height: 20),

                // Video picker
                Text(
                  'Video File',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHigh),
                ).animate(delay: 50.ms).fadeIn(),
                const SizedBox(height: 8),
                _VideoUploadTile(
                  videoPath: _videoPath,
                  isCopying: _copying,
                  onTap: (_copying || _saving) ? null : _pickVideo,
                  onClear: () => setState(() => _videoPath = ''),
                ).animate(delay: 100.ms).fadeIn(),
                const SizedBox(height: 20),

                // Transcription
                Text(
                  'Transcription',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHigh),
                ).animate(delay: 150.ms).fadeIn(),
                const SizedBox(height: 4),
                Text(
                  'Paste the full text transcription of the video. The AI uses this to answer student questions.',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.textLow),
                ).animate(delay: 160.ms).fadeIn(),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _transcriptCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Paste transcription here...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 10,
                  style: GoogleFonts.outfit(
                      fontSize: 13, height: 1.6, color: AppColors.textHigh),
                ).animate(delay: 180.ms).fadeIn(),
                const SizedBox(height: 28),

                // Phases
                PhaseEditorWidget(
                  phases: _phases,
                  onChanged: (p) => setState(() => _phases = p),
                ).animate(delay: 220.ms).fadeIn(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: Text(
            'Delete "${widget.existingLesson!.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<CourseProvider>().deleteLesson(
                  widget.courseId, widget.existingLesson!.id);
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close editor
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Animated video upload tile ───────────────────────────────────────────────

class _VideoUploadTile extends StatefulWidget {
  final String videoPath;
  final bool isCopying;
  final VoidCallback? onTap;
  final VoidCallback onClear;

  const _VideoUploadTile({
    required this.videoPath,
    required this.isCopying,
    required this.onTap,
    required this.onClear,
  });

  @override
  State<_VideoUploadTile> createState() => _VideoUploadTileState();
}

class _VideoUploadTileState extends State<_VideoUploadTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _fileName =>
      widget.videoPath.split(RegExp(r'[/\\]')).last;

  @override
  Widget build(BuildContext context) {
    // ── Uploading state ──────────────────────────────────────────────────────
    if (widget.isCopying) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: _pulseAnim.value),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(
                        AppColors.primary.withValues(alpha: _pulseAnim.value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uploading…',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          _fileName,
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.textMed),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.15),
                  valueColor:
                      AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Copying video to app storage — please wait',
                style: GoogleFonts.outfit(
                    fontSize: 11, color: AppColors.textLow),
              ),
            ],
          ),
        ),
      );
    }

    // ── Uploaded / success state ─────────────────────────────────────────────
    if (widget.videoPath.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 28)
                .animate()
                .scale(
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1.0, 1.0),
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uploaded successfully',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 2),
                  Text(
                    _fileName,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: const Color(0xFF065F46)),
                    overflow: TextOverflow.ellipsis,
                  ).animate().fadeIn(delay: 100.ms),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Change button
            GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Change',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMed),
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: widget.onClear,
              child: const Icon(Icons.close,
                  size: 18, color: AppColors.textLow),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
    }

    // ── Idle / empty state ───────────────────────────────────────────────────
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_outlined,
                size: 40, color: AppColors.textLow),
            const SizedBox(height: 10),
            Text(
              'Tap to upload a video',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMed,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'MP4 · MOV · AVI · MKV',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppColors.textLow),
            ),
          ],
        ),
      ),
    );
  }
}
