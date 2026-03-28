import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/phase_model.dart';
import '../../models/question_model.dart';
import '../../utils/theme.dart';

class PhaseQuestionOverlay extends StatefulWidget {
  final PhaseModel phase;
  final VoidCallback onComplete;
  final void Function(int correct, int total) onResults;

  const PhaseQuestionOverlay({
    super.key,
    required this.phase,
    required this.onComplete,
    required this.onResults,
  });

  @override
  State<PhaseQuestionOverlay> createState() => _PhaseQuestionOverlayState();
}

class _PhaseQuestionOverlayState extends State<PhaseQuestionOverlay> {
  int _currentIndex = 0;
  int? _selectedOption;
  bool _answered = false;
  int _correct = 0;
  bool _showSummary = false;

  QuestionModel get _question => widget.phase.questions[_currentIndex];
  bool get _isCorrect => _selectedOption == _question.correctIndex;
  bool get _hasQuestions => widget.phase.questions.isNotEmpty;

  void _select(int idx) {
    if (_answered) return;
    setState(() {
      _selectedOption = idx;
      _answered = true;
      if (idx == _question.correctIndex) _correct++;
    });
  }

  void _next() {
    if (_currentIndex < widget.phase.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _answered = false;
      });
    } else {
      setState(() => _showSummary = true);
      widget.onResults(_correct, widget.phase.questions.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              // Scroll in case content is taller than available screen
              child: SingleChildScrollView(
                child: (!_hasQuestions || _showSummary)
                    ? _SummaryView(
                        phase: widget.phase,
                        correct: _correct,
                        total: widget.phase.questions.length,
                        onContinue: widget.onComplete,
                      )
                    : _QuestionView(
                        phase: widget.phase,
                        question: _question,
                        currentIndex: _currentIndex,
                        totalQuestions: widget.phase.questions.length,
                        selectedOption: _selectedOption,
                        answered: _answered,
                        isCorrect: _answered ? _isCorrect : false,
                        onSelect: _select,
                        onNext: _next,
                      ),
              ),
            ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9)),
          ),
        ),
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  final PhaseModel phase;
  final QuestionModel question;
  final int currentIndex;
  final int totalQuestions;
  final int? selectedOption;
  final bool answered;
  final bool isCorrect;
  final void Function(int) onSelect;
  final VoidCallback onNext;

  const _QuestionView({
    required this.phase,
    required this.question,
    required this.currentIndex,
    required this.totalQuestions,
    required this.selectedOption,
    required this.answered,
    required this.isCorrect,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 400;
    return Padding(
      padding: EdgeInsets.all(compact ? 18 : 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase badge + progress
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      phase.title,
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Question ${currentIndex + 1} / $totalQuestions',
                style: GoogleFonts.outfit(
                    fontSize: 12, color: AppColors.textLow),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentIndex + 1) / totalQuestions,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 24),

          // Question text
          Text(
            question.text.isEmpty ? 'Question text not set yet.' : question.text,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textHigh,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Options
          ...List.generate(
            question.options.length,
            (i) => _OptionTile(
              label: String.fromCharCode(65 + i),
              text: question.options[i].isEmpty ? 'Option ${i + 1}' : question.options[i],
              selected: selectedOption == i,
              correct: answered && i == question.correctIndex,
              wrong: answered && selectedOption == i && i != question.correctIndex,
              onTap: () => onSelect(i),
            ),
          ),

          // Feedback
          if (answered) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCorrect ? AppColors.successLight : AppColors.errorLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? AppColors.success : AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCorrect ? 'Correct!' : 'Incorrect',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            color: isCorrect ? AppColors.success : AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                        if (question.explanation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            question.explanation,
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.textMed,
                                height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: answered ? onNext : null,
              child: Text(
                  currentIndex < totalQuestions - 1 ? 'Next Question' : 'See Results'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String text;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.text,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = AppColors.border;
    Color bgColor = AppColors.bgSurface;
    Color textColor = AppColors.textHigh;

    if (correct) {
      borderColor = AppColors.success;
      bgColor = AppColors.successLight;
      textColor = AppColors.success;
    } else if (wrong) {
      borderColor = AppColors.error;
      bgColor = AppColors.errorLight;
      textColor = AppColors.error;
    } else if (selected) {
      borderColor = AppColors.primary;
      bgColor = AppColors.primaryLight;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected || correct || wrong ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: correct
                    ? AppColors.success
                    : wrong
                        ? AppColors.error
                        : selected
                            ? AppColors.primary
                            : AppColors.border,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: selected || correct || wrong ? Colors.white : AppColors.textMed,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: selected || correct || wrong ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (correct)
              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
            if (wrong)
              const Icon(Icons.cancel, color: AppColors.error, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  final PhaseModel phase;
  final int correct;
  final int total;
  final VoidCallback onContinue;

  const _SummaryView({
    required this.phase,
    required this.correct,
    required this.total,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final score = total == 0 ? 1.0 : correct / total;
    final pct = (score * 100).round();
    final isGood = score >= 0.7;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isGood ? AppColors.successLight : AppColors.warningLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGood ? Icons.emoji_events_rounded : Icons.lightbulb_outline,
              color: isGood ? AppColors.success : AppColors.warning,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            total == 0 ? 'Phase Complete!' : 'Phase Results',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textHigh,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            total == 0
                ? 'You completed "${phase.title}". Continue to the next section!'
                : isGood
                    ? 'Great work on "${phase.title}"!'
                    : 'Keep it up! Review "${phase.title}" if needed.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMed),
            textAlign: TextAlign.center,
          ),
          if (total > 0) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ScorePill(
                  label: 'Score',
                  value: '$pct%',
                  color: isGood ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 12),
                _ScorePill(
                    label: 'Correct', value: '$correct/$total', color: AppColors.primary),
              ],
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Continue Video'),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ScorePill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMed),
          ),
        ],
      ),
    );
  }
}
