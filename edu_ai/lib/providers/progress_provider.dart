import 'package:flutter/material.dart';
import '../models/progress_model.dart';
import '../models/chat_message_model.dart';
import '../services/storage_service.dart';

class ProgressProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();

  // key: "${studentId}_${courseId}"
  final Map<String, StudentCourseProgress> _progressMap = {};

  Future<void> loadProgress() async {
    final loaded = await _storage.loadProgress();
    _progressMap.addAll(loaded);
    notifyListeners();
  }

  String _key(String studentId, String courseId) => '${studentId}_$courseId';

  StudentCourseProgress getProgress(String studentId, String courseId) {
    return _progressMap[_key(studentId, courseId)] ??
        StudentCourseProgress(
          studentId: studentId,
          courseId: courseId,
          lessonProgressMap: {},
        );
  }

  LessonProgress getLessonProgress(
      String studentId, String courseId, String lessonId) {
    final prog = getProgress(studentId, courseId);
    return prog.lessonProgressMap[lessonId] ??
        LessonProgress(
          lessonId: lessonId,
          watchedSeconds: 0,
          isCompleted: false,
          phaseResults: [],
          chatHistory: [],
          lastWatched: DateTime.now(),
        );
  }

  bool isLessonCompleted(String studentId, String courseId, String lessonId) {
    return getProgress(studentId, courseId).isLessonCompleted(lessonId);
  }

  bool isLessonUnlocked(
      String studentId, String courseId, List<String> orderedLessonIds, String lessonId) {
    final idx = orderedLessonIds.indexOf(lessonId);
    if (idx <= 0) return true; // first lesson always unlocked
    final previousId = orderedLessonIds[idx - 1];
    return getProgress(studentId, courseId).isLessonCompleted(previousId);
  }

  Future<void> updateWatchPosition(
      String studentId, String courseId, String lessonId, double seconds) async {
    final p = getLessonProgress(studentId, courseId, lessonId);
    await _updateLesson(studentId, courseId, p.copyWith(watchedSeconds: seconds, lastWatched: DateTime.now()));
  }

  Future<void> completeLesson(
      String studentId, String courseId, String lessonId) async {
    final p = getLessonProgress(studentId, courseId, lessonId);
    await _updateLesson(studentId, courseId, p.copyWith(isCompleted: true));
  }

  Future<void> recordPhaseResult(
      String studentId, String courseId, String lessonId, PhaseResult result) async {
    final p = getLessonProgress(studentId, courseId, lessonId);
    final existing = p.phaseResults.where((r) => r.phaseId != result.phaseId).toList();
    await _updateLesson(
        studentId, courseId, p.copyWith(phaseResults: [...existing, result]));
  }

  Future<void> addChatMessage(
      String studentId, String courseId, String lessonId, ChatMessageModel msg) async {
    final p = getLessonProgress(studentId, courseId, lessonId);
    await _updateLesson(
        studentId, courseId, p.copyWith(chatHistory: [...p.chatHistory, msg]));
  }

  Future<void> _updateLesson(
      String studentId, String courseId, LessonProgress lp) async {
    final key = _key(studentId, courseId);
    final existing = _progressMap[key] ??
        StudentCourseProgress(studentId: studentId, courseId: courseId, lessonProgressMap: {});
    final newMap = Map<String, LessonProgress>.from(existing.lessonProgressMap)
      ..[lp.lessonId] = lp;
    _progressMap[key] = existing.copyWith(lessonProgressMap: newMap);
    await _storage.saveProgress(_progressMap);
    notifyListeners();
  }

  // ─── Analytics helpers ──────────────────────────────────────────────────────

  /// Returns all progress entries for a given student across all courses.
  List<StudentCourseProgress> getAllProgressForStudent(String studentId) {
    return _progressMap.values
        .where((p) => p.studentId == studentId)
        .toList();
  }

  double getStudentOverallScore(String studentId) {
    final all = getAllProgressForStudent(studentId);
    int totalCorrect = 0, totalQ = 0;
    for (final cp in all) {
      for (final lp in cp.lessonProgressMap.values) {
        totalCorrect += lp.totalCorrect;
        totalQ += lp.totalQuestions;
      }
    }
    return totalQ == 0 ? 0 : totalCorrect / totalQ;
  }

  int getCompletedLessonsCount(String studentId) {
    return getAllProgressForStudent(studentId)
        .expand((cp) => cp.lessonProgressMap.values)
        .where((lp) => lp.isCompleted)
        .length;
  }
}
