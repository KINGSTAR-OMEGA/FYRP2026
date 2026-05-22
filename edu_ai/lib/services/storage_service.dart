import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/course_model.dart';
import '../models/progress_model.dart';
import '../models/question_model.dart';
import '../models/student_memory_model.dart';
import '../models/user_model.dart';

class StorageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Seed Database ──────────────────────────────────────────────────────────
  // Checks if the database is empty, and if so, seeds it with initial demo admin, students, and courses
  Future<void> seedDatabaseIfNeeded() async {
    try {
      final studentSnapshot = await _db.collection('students').limit(1).get();
      final teacherSnapshot = await _db.collection('teachers').limit(1).get();
      if (studentSnapshot.docs.isEmpty && teacherSnapshot.docs.isEmpty) {
        print('Firestore is empty. Seeding initial users...');

        // 1. Seed Admin
        try {
          await _auth.createUserWithEmailAndPassword(
            email: 'admin@eduai.com',
            password: 'admin123',
          );
          final uid = _auth.currentUser?.uid ?? 'admin_1';
          await _db.collection('teachers').doc(uid).set({
            'id': uid,
            'name': 'Admin User',
            'email': 'admin@eduai.com',
            'role': 'admin',
          });
          await _auth.signOut();
        } catch (e) {
          // If already exists or auth creation fails, save to Firestore with default ID
          await _db.collection('teachers').doc('admin_1').set({
            'id': 'admin_1',
            'name': 'Admin User',
            'email': 'admin@eduai.com',
            'role': 'admin',
          });
        }

        // 2. Seed Students
        final studentsList = [
          {'name': 'Rashmi', 'email': 'rashmi@eduai.com'},
          {'name': 'Rishikesh', 'email': 'rishikesh@eduai.com'},
          {'name': 'Jyoti', 'email': 'jyoti@eduai.com'},
          {'name': 'Aditya', 'email': 'aditya@eduai.com'},
        ];

        for (final student in studentsList) {
          try {
            await _auth.createUserWithEmailAndPassword(
              email: student['email']!,
              password: 'student123',
            );
            final uid = _auth.currentUser?.uid ?? '';
            await _db.collection('students').doc(uid).set({
              'id': uid,
              'name': student['name']!,
              'email': student['email']!,
              'role': 'student',
            });
            await _auth.signOut();
          } catch (e) {
            // Fallback to name-based ID
            final id = student['name']!.toLowerCase();
            await _db.collection('students').doc(id).set({
              'id': id,
              'name': student['name']!,
              'email': student['email']!,
              'role': 'student',
            });
          }
        }

        print('Firestore database successfully seeded.');
      }
    } catch (e) {
      print('Error during database seeding: $e');
    }
  }

  // ─── Courses ────────────────────────────────────────────────────────────────

  Future<List<CourseModel>> loadCourses() async {
    try {
      final snapshot = await _db.collection('courses').get();
      final list = snapshot.docs
          .map((doc) => CourseModel.fromJson(doc.data()))
          .toList();
      // Sort courses by creation date
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    } catch (e) {
      print('Error loading courses from Firestore: $e');
      return [];
    }
  }

  Future<void> saveCourses(List<CourseModel> courses) async {
    try {
      for (final course in courses) {
        await _db.collection('courses').doc(course.id).set(course.toJson());
      }
    } catch (e) {
      print('Error saving courses to Firestore: $e');
    }
  }

  Future<void> saveCourse(CourseModel course) async {
    try {
      await _db.collection('courses').doc(course.id).set(course.toJson());
    } catch (e) {
      print('Error saving course: $e');
    }
  }

  Future<void> deleteCourse(String courseId) async {
    try {
      await _db.collection('courses').doc(courseId).delete();
    } catch (e) {
      print('Error deleting course from Firestore: $e');
    }
  }

  // ─── Progress ───────────────────────────────────────────────────────────────

  Future<Map<String, StudentCourseProgress>> loadProgress() async {
    try {
      final snapshot = await _db.collection('progress').get();
      final Map<String, StudentCourseProgress> map = {};
      for (final doc in snapshot.docs) {
        final progress = StudentCourseProgress.fromJson(doc.data());
        final key = '${progress.studentId}_${progress.courseId}';
        map[key] = progress;
      }
      return map;
    } catch (e) {
      print('Error loading progress from Firestore: $e');
      return {};
    }
  }

  Future<void> saveProgress(Map<String, StudentCourseProgress> progress) async {
    try {
      for (final entry in progress.entries) {
        final key = entry.key; // studentId_courseId
        await _db.collection('progress').doc(key).set(entry.value.toJson());
      }
    } catch (e) {
      print('Error saving progress to Firestore: $e');
    }
  }

  // ─── Student Memory ──────────────────────────────────────────────────────────

  Future<StudentMemoryModel?> loadStudentMemory(String studentId) async {
    try {
      final doc = await _db.collection('student_memory').doc(studentId).get();
      if (doc.exists && doc.data() != null) {
        return StudentMemoryModel.fromJson(doc.data()!);
      }
    } catch (e) {
      print('Error loading memory from Firestore: $e');
    }
    return null;
  }

  Future<void> saveStudentMemory(StudentMemoryModel memory) async {
    try {
      await _db
          .collection('student_memory')
          .doc(memory.studentId)
          .set(memory.toJson());
    } catch (e) {
      print('Error saving memory to Firestore: $e');
    }
  }

  // ─── Cached AI Questions ─────────────────────────────────────────────────────

  Future<List<QuestionModel>?> loadCachedAiQuestions(
      String lessonId, String phaseId, String studentId) async {
    try {
      final key = '${lessonId}_${phaseId}_$studentId';
      final doc = await _db.collection('ai_questions').doc(key).get();
      if (doc.exists && doc.data() != null) {
        final list = doc.data()!['questions'] as List;
        return list
            .map((j) => QuestionModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error loading cached questions from Firestore: $e');
    }
    return null;
  }

  Future<void> saveCachedAiQuestions(
      String lessonId,
      String phaseId,
      String studentId,
      List<QuestionModel> questions) async {
    try {
      final key = '${lessonId}_${phaseId}_$studentId';
      await _db.collection('ai_questions').doc(key).set({
        'lessonId': lessonId,
        'phaseId': phaseId,
        'studentId': studentId,
        'questions': questions.map((q) => q.toJson()).toList(),
        'cachedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving cached questions to Firestore: $e');
    }
  }
}
