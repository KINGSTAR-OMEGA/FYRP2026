import 'chat_message_model.dart';

class PhaseResult {
  final String phaseId;
  final int correct;
  final int total;
  final DateTime completedAt;

  const PhaseResult({
    required this.phaseId,
    required this.correct,
    required this.total,
    required this.completedAt,
  });

  double get score => total == 0 ? 0 : correct / total;

  factory PhaseResult.fromJson(Map<String, dynamic> json) => PhaseResult(
        phaseId: json['phaseId'] as String,
        correct: json['correct'] as int,
        total: json['total'] as int,
        completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'phaseId': phaseId,
        'correct': correct,
        'total': total,
        'completedAt': completedAt.toIso8601String(),
      };
}

class LessonProgress {
  final String lessonId;
  final double watchedSeconds;
  final bool isCompleted;
  final List<PhaseResult> phaseResults;
  final List<ChatMessageModel> chatHistory;
  final DateTime lastWatched;

  const LessonProgress({
    required this.lessonId,
    required this.watchedSeconds,
    required this.isCompleted,
    required this.phaseResults,
    required this.chatHistory,
    required this.lastWatched,
  });

  Set<String> get completedPhaseIds => phaseResults.map((r) => r.phaseId).toSet();

  int get totalCorrect => phaseResults.fold(0, (s, r) => s + r.correct);
  int get totalQuestions => phaseResults.fold(0, (s, r) => s + r.total);
  double get overallScore => totalQuestions == 0 ? 0 : totalCorrect / totalQuestions;

  LessonProgress copyWith({
    String? lessonId,
    double? watchedSeconds,
    bool? isCompleted,
    List<PhaseResult>? phaseResults,
    List<ChatMessageModel>? chatHistory,
    DateTime? lastWatched,
  }) =>
      LessonProgress(
        lessonId: lessonId ?? this.lessonId,
        watchedSeconds: watchedSeconds ?? this.watchedSeconds,
        isCompleted: isCompleted ?? this.isCompleted,
        phaseResults: phaseResults ?? this.phaseResults,
        chatHistory: chatHistory ?? this.chatHistory,
        lastWatched: lastWatched ?? this.lastWatched,
      );

  factory LessonProgress.fromJson(Map<String, dynamic> json) => LessonProgress(
        lessonId: json['lessonId'] as String,
        watchedSeconds: (json['watchedSeconds'] as num?)?.toDouble() ?? 0,
        isCompleted: json['isCompleted'] as bool? ?? false,
        phaseResults: (json['phaseResults'] as List? ?? [])
            .map((r) => PhaseResult.fromJson(r as Map<String, dynamic>))
            .toList(),
        chatHistory: (json['chatHistory'] as List? ?? [])
            .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
            .toList(),
        lastWatched: DateTime.tryParse(json['lastWatched'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'lessonId': lessonId,
        'watchedSeconds': watchedSeconds,
        'isCompleted': isCompleted,
        'phaseResults': phaseResults.map((r) => r.toJson()).toList(),
        'chatHistory': chatHistory.map((m) => m.toJson()).toList(),
        'lastWatched': lastWatched.toIso8601String(),
      };
}

class StudentCourseProgress {
  final String studentId;
  final String courseId;
  final Map<String, LessonProgress> lessonProgressMap; // lessonId -> progress

  const StudentCourseProgress({
    required this.studentId,
    required this.courseId,
    required this.lessonProgressMap,
  });

  LessonProgress? getLesson(String lessonId) => lessonProgressMap[lessonId];

  bool isLessonCompleted(String lessonId) =>
      lessonProgressMap[lessonId]?.isCompleted ?? false;

  StudentCourseProgress copyWith({
    String? studentId,
    String? courseId,
    Map<String, LessonProgress>? lessonProgressMap,
  }) =>
      StudentCourseProgress(
        studentId: studentId ?? this.studentId,
        courseId: courseId ?? this.courseId,
        lessonProgressMap: lessonProgressMap ?? this.lessonProgressMap,
      );

  factory StudentCourseProgress.fromJson(Map<String, dynamic> json) =>
      StudentCourseProgress(
        studentId: json['studentId'] as String,
        courseId: json['courseId'] as String,
        lessonProgressMap: (json['lessonProgressMap'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, LessonProgress.fromJson(v as Map<String, dynamic>))),
      );

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'courseId': courseId,
        'lessonProgressMap':
            lessonProgressMap.map((k, v) => MapEntry(k, v.toJson())),
      };
}
