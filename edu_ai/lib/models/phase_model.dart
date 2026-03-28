import 'question_model.dart';

class PhaseModel {
  final String id;
  final String title;
  final double endTimeSeconds; // video timestamp when this phase ends
  final List<QuestionModel> questions;

  const PhaseModel({
    required this.id,
    required this.title,
    required this.endTimeSeconds,
    required this.questions,
  });

  factory PhaseModel.fromJson(Map<String, dynamic> json) => PhaseModel(
        id: json['id'] as String,
        title: json['title'] as String,
        endTimeSeconds: (json['endTimeSeconds'] as num).toDouble(),
        questions: (json['questions'] as List)
            .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'endTimeSeconds': endTimeSeconds,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  PhaseModel copyWith({
    String? id,
    String? title,
    double? endTimeSeconds,
    List<QuestionModel>? questions,
  }) =>
      PhaseModel(
        id: id ?? this.id,
        title: title ?? this.title,
        endTimeSeconds: endTimeSeconds ?? this.endTimeSeconds,
        questions: questions ?? this.questions,
      );
}
