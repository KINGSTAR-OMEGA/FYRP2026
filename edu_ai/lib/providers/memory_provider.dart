import 'package:flutter/material.dart';
import '../models/student_memory_model.dart';
import '../services/storage_service.dart';

class MemoryProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();

  // Keyed by studentId — supports multiple demo accounts in one session
  final Map<String, StudentMemoryModel> _cache = {};

  StudentMemoryModel getMemory(String studentId) =>
      _cache[studentId] ?? StudentMemoryModel.empty(studentId);

  Future<void> loadMemory(String studentId) async {
    final loaded = await _storage.loadStudentMemory(studentId);
    _cache[studentId] = loaded ?? StudentMemoryModel.empty(studentId);
    notifyListeners();
  }

  Future<void> saveMemory(StudentMemoryModel memory) async {
    _cache[memory.studentId] = memory;
    await _storage.saveStudentMemory(memory);
    notifyListeners();
  }

  /// Called after every answered question.
  /// Uses a weighted moving average (weight = 0.15) so recent answers
  /// influence the score without completely discarding history.
  Future<void> recordAnswer({
    required String studentId,
    required String topic,
    required bool wasCorrect,
  }) async {
    final mem = getMemory(studentId);

    final oldScore = mem.topicScores[topic] ?? 0.5;
    const weight = 0.15;
    final newScore = wasCorrect
        ? oldScore + weight * (1.0 - oldScore)
        : oldScore - weight * oldScore;
    final updatedScores = Map<String, double>.from(mem.topicScores)
      ..[topic] = newScore.clamp(0.0, 1.0);

    // Reclassify strength / weakness thresholds: 80% = strength, 50% = weakness
    final strengths = List<String>.from(mem.strengths);
    final weaknesses = List<String>.from(mem.weaknesses);
    if (newScore >= 0.80 && !strengths.contains(topic)) {
      strengths.add(topic);
      weaknesses.remove(topic);
    } else if (newScore < 0.50 && !weaknesses.contains(topic)) {
      weaknesses.add(topic);
      strengths.remove(topic);
    }

    await saveMemory(mem.copyWith(
      topicScores: updatedScores,
      strengths: strengths,
      weaknesses: weaknesses,
      totalQuestionsAttempted: mem.totalQuestionsAttempted + 1,
      totalCorrect: mem.totalCorrect + (wasCorrect ? 1 : 0),
      lastUpdated: DateTime.now(),
    ));
  }

  /// Called when Grok returns learning-style or confusion insights.
  Future<void> updateLearningInsights({
    required String studentId,
    String? learningStyle,
    String? preferredPace,
    List<String>? newConfusionPoints,
  }) async {
    final mem = getMemory(studentId);
    final mergedConfusion = newConfusionPoints == null
        ? null
        : [...mem.confusionPoints, ...newConfusionPoints];
    await saveMemory(mem.copyWith(
      learningStyle: learningStyle,
      preferredPace: preferredPace,
      confusionPoints: mergedConfusion,
    ));
  }
}
