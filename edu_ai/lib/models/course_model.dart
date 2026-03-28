import 'lesson_model.dart';

class CourseModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final List<LessonModel> lessons;
  final DateTime createdAt;

  const CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.lessons,
    required this.createdAt,
  });

  int get totalLessons => lessons.length;

  factory CourseModel.fromJson(Map<String, dynamic> json) => CourseModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'General',
        lessons: (json['lessons'] as List)
            .map((l) => LessonModel.fromJson(l as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'lessons': lessons.map((l) => l.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  CourseModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    List<LessonModel>? lessons,
    DateTime? createdAt,
  }) =>
      CourseModel(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        lessons: lessons ?? this.lessons,
        createdAt: createdAt ?? this.createdAt,
      );
}
