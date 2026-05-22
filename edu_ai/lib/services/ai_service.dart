import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/question_model.dart';
import '../models/student_memory_model.dart';

class AiService {
  static final _client = http.Client();
  static const _uuid = Uuid();

  // ─── Internal HTTP helper ────────────────────────────────────────────────────

  Future<String> _chat({
    required List<Map<String, String>> messages,
    String model = AppConfig.grokChatModel,
    double temperature = 0.7,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${AppConfig.grokBaseUrl}/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${AppConfig.grokApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'temperature': temperature,
          }),
        )
        .timeout(AppConfig.apiTimeout);

    if (response.statusCode != 200) {
      throw Exception(
          'Grok API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['choices'] as List).first['message']['content'] as String;
  }

  // ─── Public: Chatbot ─────────────────────────────────────────────────────────

  Future<String> ask({
    required String question,
    required String transcription,
    required List<Map<String, String>> history,
    StudentMemoryModel? studentMemory,
  }) async {
    final systemPrompt = _buildChatSystemPrompt(transcription, studentMemory);

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      // Replay last 10 messages to save tokens
      ...history.takeLast(10).map((m) => {
            'role': m['role'] == 'ai' ? 'assistant' : 'user',
            'content': m['content'] ?? '',
          }),
      {'role': 'user', 'content': question},
    ];

    try {
      return await _chat(messages: messages);
    } catch (_) {
      return _fallbackAsk(question, transcription);
    }
  }

  // ─── Public: Phase Question Generation ──────────────────────────────────────

  /// Computes the target question count per phase based on video duration.
  /// Formula: ceil(durationSeconds / 600), clamped to [1, 3].
  /// Examples: 0–10 min → 1 Q, 10–20 min → 2 Q, 20+ min → 3 Q.
  static int computeQuestionCount(double videoDurationSeconds) =>
      (videoDurationSeconds / 600).ceil().clamp(1, 3);

  /// Returns AI-generated questions, or null on failure (caller falls back to admin questions).
  Future<List<QuestionModel>?> generatePhaseQuestions({
    required String transcription,
    required String phaseTitle,
    required double videoDurationSeconds,
    required String lessonTitle,
    StudentMemoryModel? studentMemory,
  }) async {
    final count = computeQuestionCount(videoDurationSeconds);
    final prompt = _buildQuestionGenerationPrompt(
      transcription: transcription,
      phaseTitle: phaseTitle,
      lessonTitle: lessonTitle,
      count: count,
      studentMemory: studentMemory,
    );

    try {
      final raw = await _chat(
        messages: [
          {
            'role': 'system',
            'content':
                'You are an expert educational assessment designer. Always respond with valid JSON only, no markdown fences.',
          },
          {'role': 'user', 'content': prompt},
        ],
        temperature: 0.5,
      );
      return _parseGeneratedQuestions(raw);
    } catch (_) {
      return null;
    }
  }

  // Legacy stub kept for backward compatibility with any existing call sites.
  Future<List<String>> generateQuestions({
    required String transcription,
    required String phaseTitle,
    int count = 2,
  }) async {
    final qs = await generatePhaseQuestions(
      transcription: transcription,
      phaseTitle: phaseTitle,
      videoDurationSeconds: 600.0,
      lessonTitle: phaseTitle,
    );
    return qs?.map((q) => q.text).toList() ??
        List.generate(
            count, (i) => 'Question ${i + 1} about "$phaseTitle"');
  }

  // ─── Public: Performance Analysis ───────────────────────────────────────────

  Future<String> analyzePerformance({
    required StudentMemoryModel memory,
    required String recentPhaseTitle,
    required int recentCorrect,
    required int recentTotal,
  }) async {
    final prompt = _buildPerformanceAnalysisPrompt(
      memory: memory,
      recentPhaseTitle: recentPhaseTitle,
      recentCorrect: recentCorrect,
      recentTotal: recentTotal,
    );

    try {
      return await _chat(
        messages: [
          {
            'role': 'system',
            'content':
                'You are a supportive AI learning coach. Be concise (2-3 sentences). Speak directly to the student.',
          },
          {'role': 'user', 'content': prompt},
        ],
        temperature: 0.8,
      );
    } catch (_) {
      return 'Keep it up! Review any topics where you felt unsure and revisit this section if needed.';
    }
  }

  // ─── Prompt Builders ─────────────────────────────────────────────────────────

  String _buildChatSystemPrompt(
      String transcription, StudentMemoryModel? memory) {
    final memSection = memory == null
        ? ''
        : '''
Student learning profile:
- Strengths: ${memory.strengths.isEmpty ? 'not yet identified' : memory.strengths.join(', ')}
- Weaknesses: ${memory.weaknesses.isEmpty ? 'none identified yet' : memory.weaknesses.join(', ')}
- Learning style: ${memory.learningStyle}
- Preferred pace: ${memory.preferredPace}
- Overall accuracy: ${(memory.overallAccuracy * 100).round()}%
- Confusion points: ${memory.confusionPoints.isEmpty ? 'none' : memory.confusionPoints.join(', ')}

Adapt your explanations to this student's learning style and proactively address their weaknesses.
''';

    final truncated = transcription.length > 4000
        ? '${transcription.substring(0, 4000)}...[truncated]'
        : transcription;

    return '''
You are a personalized AI tutor embedded in an educational video platform.

VIDEO LESSON TRANSCRIPTION:
"""
$truncated
"""

$memSection
INSTRUCTIONS:
- Answer questions based on the lesson transcription above.
- Be clear, encouraging, and concise (under 200 words unless a detailed explanation is requested).
- Tailor your explanation style to the student's learning style.
- If the student has a weakness in a topic covered in your answer, offer extra clarification proactively.
- If asked for an example, give a concrete, relatable one tied to the transcription content.
- If asked to summarize, produce bullet points covering the main ideas.
- Do not invent facts not present in the transcription.
''';
  }

  String _buildQuestionGenerationPrompt({
    required String transcription,
    required String phaseTitle,
    required String lessonTitle,
    required int count,
    StudentMemoryModel? studentMemory,
  }) {
    String difficultyNote;
    if (studentMemory == null) {
      difficultyNote = 'Use a balanced mix of recall and application questions.';
    } else if (studentMemory.overallAccuracy < 0.50) {
      difficultyNote =
          'This student struggles. Focus questions on foundational concepts covered explicitly in the transcription.';
    } else if (studentMemory.overallAccuracy > 0.80) {
      difficultyNote =
          'This student excels. Include at least one application or "why" question requiring deeper thinking.';
    } else {
      difficultyNote = 'Mix recall and understanding questions equally.';
    }

    final weaknessNote =
        studentMemory != null && studentMemory.weaknesses.isNotEmpty
            ? 'Prioritize questions about these weak topics if they appear in the transcription: ${studentMemory.weaknesses.join(', ')}.'
            : '';

    final truncated = transcription.length > 3000
        ? transcription.substring(0, 3000)
        : transcription;

    return '''
Generate exactly $count multiple-choice quiz questions for a video lesson phase.

LESSON: $lessonTitle
PHASE: $phaseTitle

TRANSCRIPTION EXCERPT:
"""
$truncated
"""

DIFFICULTY GUIDANCE: $difficultyNote
$weaknessNote

RULES:
1. Each question must be directly answerable from the transcription.
2. Each question must have exactly 4 options.
3. Exactly one option must be correct.
4. The explanation must state why the correct answer is right (1-2 sentences).
5. Return ONLY a raw JSON array, no markdown, no extra keys.

REQUIRED JSON FORMAT:
[
  {
    "text": "Question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "explanation": "Option A is correct because..."
  }
]
''';
  }

  String _buildPerformanceAnalysisPrompt({
    required StudentMemoryModel memory,
    required String recentPhaseTitle,
    required int recentCorrect,
    required int recentTotal,
  }) =>
      '''
A student just completed a quiz phase titled "$recentPhaseTitle".
Results: $recentCorrect/$recentTotal correct.

Their cumulative learning profile:
- Overall accuracy: ${(memory.overallAccuracy * 100).round()}%
- Strengths: ${memory.strengths.isEmpty ? 'none yet' : memory.strengths.join(', ')}
- Weaknesses: ${memory.weaknesses.isEmpty ? 'none identified' : memory.weaknesses.join(', ')}
- Learning style: ${memory.learningStyle}
- Total questions attempted so far: ${memory.totalQuestionsAttempted}

Write a short, personalized (2-3 sentence) motivational insight that:
1. Acknowledges their recent quiz performance specifically.
2. Gives one actionable tip based on their weaknesses or strengths.
3. Is warm, encouraging, and addresses the student as "you".
''';

  // ─── JSON Parser ─────────────────────────────────────────────────────────────

  List<QuestionModel> _parseGeneratedQuestions(String raw) {
    var cleaned = raw.trim();
    // Strip markdown fences the model may add despite instructions
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```[a-z]*\n?'), '')
          .replaceFirst(RegExp(r'```$'), '')
          .trim();
    }

    final list = jsonDecode(cleaned) as List;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final options = List<String>.from(map['options'] as List);
      while (options.length < 4) {
        options.add('N/A');
      }
      return QuestionModel(
        id: _uuid.v4(),
        text: map['text'] as String,
        options: options.take(4).toList(),
        correctIndex: (map['correctIndex'] as int).clamp(0, 3),
        explanation: map['explanation'] as String? ?? '',
      );
    }).toList();
  }

  // ─── Fallback ─────────────────────────────────────────────────────────────────

  String _fallbackAsk(String question, String transcription) {
    final q = question.toLowerCase();
    if (q.contains('summar') || q.contains('overview')) {
      return 'Here is a summary of the lesson content:\n\n'
          '• ${_firstSentence(transcription)}\n\n'
          'The content builds from foundational concepts toward advanced ideas. '
          'Ask me to elaborate on any specific section.';
    }
    return 'I\'m currently unable to reach the AI service. '
        'Please check your connection and try again. '
        'In the meantime, the lesson transcription is available in the video description.';
  }

  String _firstSentence(String text) {
    if (text.isEmpty) return 'the lesson content';
    final end = text.indexOf(RegExp(r'[.!?]'));
    return end == -1
        ? text.substring(0, text.length.clamp(0, 80))
        : text.substring(0, end + 1);
  }
}

extension _ListTakeLast<T> on List<T> {
  List<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}
