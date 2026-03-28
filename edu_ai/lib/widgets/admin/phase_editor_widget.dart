import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../models/phase_model.dart';
import '../../models/question_model.dart';
import '../../utils/theme.dart';

class PhaseEditorWidget extends StatefulWidget {
  final List<PhaseModel> phases;
  final ValueChanged<List<PhaseModel>> onChanged;

  const PhaseEditorWidget({
    super.key,
    required this.phases,
    required this.onChanged,
  });

  @override
  State<PhaseEditorWidget> createState() => _PhaseEditorWidgetState();
}

class _PhaseEditorWidgetState extends State<PhaseEditorWidget> {
  late List<PhaseModel> _phases;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _phases = List.from(widget.phases);
  }

  void _addPhase() {
    final phase = PhaseModel(
      id: _uuid.v4(),
      title: 'Phase ${_phases.length + 1}',
      endTimeSeconds: 60.0 * (_phases.length + 1),
      questions: [],
    );
    setState(() => _phases.add(phase));
    widget.onChanged(_phases);
  }

  void _removePhase(int idx) {
    setState(() => _phases.removeAt(idx));
    widget.onChanged(_phases);
  }

  void _editPhase(int idx, PhaseModel updated) {
    setState(() => _phases[idx] = updated);
    widget.onChanged(_phases);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Video Phases',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textHigh,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addPhase,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Phase'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_phases.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                'No phases yet. Add a phase to create checkpoint questions.',
                style: GoogleFonts.outfit(
                  color: AppColors.textLow,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ...List.generate(
            _phases.length,
            (i) => _PhaseCard(
              phase: _phases[i],
              index: i,
              onDelete: () => _removePhase(i),
              onUpdate: (updated) => _editPhase(i, updated),
            ),
          ),
      ],
    );
  }
}

class _PhaseCard extends StatefulWidget {
  final PhaseModel phase;
  final int index;
  final VoidCallback onDelete;
  final ValueChanged<PhaseModel> onUpdate;

  const _PhaseCard({
    required this.phase,
    required this.index,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_PhaseCard> createState() => _PhaseCardState();
}

class _PhaseCardState extends State<_PhaseCard> {
  bool _expanded = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _timeCtrl;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.phase.title);
    _timeCtrl =
        TextEditingController(text: widget.phase.endTimeSeconds.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onUpdate(widget.phase.copyWith(
      title: _titleCtrl.text,
      endTimeSeconds: double.tryParse(_timeCtrl.text) ?? widget.phase.endTimeSeconds,
    ));
  }

  void _addQuestion() {
    final q = QuestionModel(
      id: _uuid.v4(),
      text: '',
      options: ['', '', '', ''],
      correctIndex: 0,
      explanation: '',
    );
    widget.onUpdate(widget.phase.copyWith(
      questions: [...widget.phase.questions, q],
    ));
  }

  void _removeQuestion(int idx) {
    final qs = List<QuestionModel>.from(widget.phase.questions)..removeAt(idx);
    widget.onUpdate(widget.phase.copyWith(questions: qs));
  }

  void _updateQuestion(int idx, QuestionModel q) {
    final qs = List<QuestionModel>.from(widget.phase.questions)..[idx] = q;
    widget.onUpdate(widget.phase.copyWith(questions: qs));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            borderRadius:
                BorderRadius.vertical(top: const Radius.circular(12), bottom: Radius.circular(_expanded ? 0 : 12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index + 1}',
                        style: GoogleFonts.outfit(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.phase.title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textHigh,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.phase.endTimeSeconds.toStringAsFixed(0)}s  •  ${widget.phase.questions.length} Q',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLow),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textLow,
                    size: 20,
                  ),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.error,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Phase Title',
                            isDense: true,
                          ),
                          onEditingComplete: _save,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _timeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'End Time (s)',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onEditingComplete: _save,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Questions (${widget.phase.questions.length})',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textHigh,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Question'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: GoogleFonts.outfit(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  ...List.generate(
                    widget.phase.questions.length,
                    (qi) => _QuestionEditor(
                      question: widget.phase.questions[qi],
                      index: qi,
                      onDelete: () => _removeQuestion(qi),
                      onUpdate: (q) => _updateQuestion(qi, q),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionEditor extends StatefulWidget {
  final QuestionModel question;
  final int index;
  final VoidCallback onDelete;
  final ValueChanged<QuestionModel> onUpdate;

  const _QuestionEditor({
    required this.question,
    required this.index,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late TextEditingController _textCtrl;
  late List<TextEditingController> _optionCtrls;
  late TextEditingController _explainCtrl;
  late int _correctIndex;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.question.text);
    _optionCtrls = widget.question.options
        .map((o) => TextEditingController(text: o))
        .toList();
    _explainCtrl = TextEditingController(text: widget.question.explanation);
    _correctIndex = widget.question.correctIndex;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    for (final c in _optionCtrls) { c.dispose(); }
    _explainCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onUpdate(widget.question.copyWith(
      text: _textCtrl.text,
      options: _optionCtrls.map((c) => c.text).toList(),
      correctIndex: _correctIndex,
      explanation: _explainCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Q${widget.index + 1}',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.close, size: 16),
                color: AppColors.textLow,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          TextFormField(
            controller: _textCtrl,
            decoration: const InputDecoration(
              labelText: 'Question text',
              isDense: true,
            ),
            maxLines: 2,
            onEditingComplete: _save,
          ),
          const SizedBox(height: 8),
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _correctIndex = i);
                      _save();
                    },
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _correctIndex == i
                              ? AppColors.success
                              : AppColors.border,
                          width: 2,
                        ),
                        color: _correctIndex == i
                            ? AppColors.success
                            : Colors.transparent,
                      ),
                      child: _correctIndex == i
                          ? const Icon(Icons.check,
                              size: 10, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextFormField(
                      controller: _optionCtrls[i],
                      decoration: InputDecoration(
                        labelText: 'Option ${String.fromCharCode(65 + i)}',
                        isDense: true,
                      ),
                      onEditingComplete: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextFormField(
            controller: _explainCtrl,
            decoration: const InputDecoration(
              labelText: 'Explanation (shown after answer)',
              isDense: true,
            ),
            onEditingComplete: _save,
          ),
        ],
      ),
    );
  }
}
