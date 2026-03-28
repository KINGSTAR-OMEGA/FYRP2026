import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_model.dart';
import '../models/progress_model.dart';

class StorageService {
  static const _coursesKey = 'edu_courses_v1';
  static const _progressKey = 'edu_progress_v1';

  // ─── Courses ────────────────────────────────────────────────────────────────

  Future<List<CourseModel>> loadCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_coursesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => CourseModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCourses(List<CourseModel> courses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _coursesKey, jsonEncode(courses.map((c) => c.toJson()).toList()));
  }

  // ─── Progress ───────────────────────────────────────────────────────────────

  Future<Map<String, StudentCourseProgress>> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) =>
          MapEntry(k, StudentCourseProgress.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveProgress(Map<String, StudentCourseProgress> progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _progressKey, jsonEncode(progress.map((k, v) => MapEntry(k, v.toJson()))));
  }
}
