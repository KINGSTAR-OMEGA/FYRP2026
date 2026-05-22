class StudentMemoryModel {
  final String studentId;
  final List<String> strengths;
  final List<String> weaknesses;
  final String learningStyle; // 'conceptual' | 'visual' | 'example-based' | 'practice-based'
  final String preferredPace; // 'slow' | 'normal' | 'fast'
  final Map<String, double> topicScores; // topic → 0.0–1.0 accuracy
  final List<String> confusionPoints;
  final int totalQuestionsAttempted;
  final int totalCorrect;
  final DateTime lastUpdated;

  const StudentMemoryModel({
    required this.studentId,
    required this.strengths,
    required this.weaknesses,
    required this.learningStyle,
    required this.preferredPace,
    required this.topicScores,
    required this.confusionPoints,
    required this.totalQuestionsAttempted,
    required this.totalCorrect,
    required this.lastUpdated,
  });

  double get overallAccuracy =>
      totalQuestionsAttempted == 0 ? 0.0 : totalCorrect / totalQuestionsAttempted;

  factory StudentMemoryModel.empty(String studentId) => StudentMemoryModel(
        studentId: studentId,
        strengths: const [],
        weaknesses: const [],
        learningStyle: 'conceptual',
        preferredPace: 'normal',
        topicScores: const {},
        confusionPoints: const [],
        totalQuestionsAttempted: 0,
        totalCorrect: 0,
        lastUpdated: DateTime.now(),
      );

  factory StudentMemoryModel.fromJson(Map<String, dynamic> json) =>
      StudentMemoryModel(
        studentId: json['studentId'] as String,
        strengths: List<String>.from(json['strengths'] as List? ?? []),
        weaknesses: List<String>.from(json['weaknesses'] as List? ?? []),
        learningStyle: json['learningStyle'] as String? ?? 'conceptual',
        preferredPace: json['preferredPace'] as String? ?? 'normal',
        topicScores: (json['topicScores'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        confusionPoints:
            List<String>.from(json['confusionPoints'] as List? ?? []),
        totalQuestionsAttempted:
            json['totalQuestionsAttempted'] as int? ?? 0,
        totalCorrect: json['totalCorrect'] as int? ?? 0,
        lastUpdated:
            DateTime.tryParse(json['lastUpdated'] as String? ?? '') ??
                DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'learningStyle': learningStyle,
        'preferredPace': preferredPace,
        'topicScores': topicScores,
        'confusionPoints': confusionPoints,
        'totalQuestionsAttempted': totalQuestionsAttempted,
        'totalCorrect': totalCorrect,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  StudentMemoryModel copyWith({
    List<String>? strengths,
    List<String>? weaknesses,
    String? learningStyle,
    String? preferredPace,
    Map<String, double>? topicScores,
    List<String>? confusionPoints,
    int? totalQuestionsAttempted,
    int? totalCorrect,
    DateTime? lastUpdated,
  }) =>
      StudentMemoryModel(
        studentId: studentId,
        strengths: strengths ?? List.from(this.strengths),
        weaknesses: weaknesses ?? List.from(this.weaknesses),
        learningStyle: learningStyle ?? this.learningStyle,
        preferredPace: preferredPace ?? this.preferredPace,
        topicScores: topicScores ?? Map.from(this.topicScores),
        confusionPoints: confusionPoints ?? List.from(this.confusionPoints),
        totalQuestionsAttempted:
            totalQuestionsAttempted ?? this.totalQuestionsAttempted,
        totalCorrect: totalCorrect ?? this.totalCorrect,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}
