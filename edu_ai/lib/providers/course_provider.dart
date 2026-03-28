import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../models/lesson_model.dart';
import '../services/storage_service.dart';

class CourseProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  List<CourseModel> _courses = [];
  bool _isLoading = false;

  List<CourseModel> get courses => List.unmodifiable(_courses);
  bool get isLoading => _isLoading;

  CourseModel? getCourse(String id) {
    try {
      return _courses.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();
    _courses = await _storage.loadCourses();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCourse(CourseModel course) async {
    _courses.add(course);
    await _storage.saveCourses(_courses);
    notifyListeners();
  }

  Future<void> updateCourse(CourseModel updated) async {
    final idx = _courses.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _courses[idx] = updated;
      await _storage.saveCourses(_courses);
      notifyListeners();
    }
  }

  Future<void> deleteCourse(String courseId) async {
    _courses.removeWhere((c) => c.id == courseId);
    await _storage.saveCourses(_courses);
    notifyListeners();
  }

  Future<void> addLessonToCourse(String courseId, LessonModel lesson) async {
    final idx = _courses.indexWhere((c) => c.id == courseId);
    if (idx == -1) return;
    final course = _courses[idx];
    final updatedLessons = [...course.lessons, lesson]
      ..sort((a, b) => a.order.compareTo(b.order));
    _courses[idx] = course.copyWith(lessons: updatedLessons);
    await _storage.saveCourses(_courses);
    notifyListeners();
  }

  Future<void> updateLesson(String courseId, LessonModel updated) async {
    final courseIdx = _courses.indexWhere((c) => c.id == courseId);
    if (courseIdx == -1) return;
    final course = _courses[courseIdx];
    final lessons = course.lessons.map((l) => l.id == updated.id ? updated : l).toList();
    _courses[courseIdx] = course.copyWith(lessons: lessons);
    await _storage.saveCourses(_courses);
    notifyListeners();
  }

  Future<void> deleteLesson(String courseId, String lessonId) async {
    final courseIdx = _courses.indexWhere((c) => c.id == courseId);
    if (courseIdx == -1) return;
    final course = _courses[courseIdx];
    final lessons = course.lessons.where((l) => l.id != lessonId).toList();
    _courses[courseIdx] = course.copyWith(lessons: lessons);
    await _storage.saveCourses(_courses);
    notifyListeners();
  }
}
