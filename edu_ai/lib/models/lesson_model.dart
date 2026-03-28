import 'phase_model.dart';

class LessonModel {
  final String id;
  final String title;
  final String videoPath; // local file path
  final String transcription;
  final List<PhaseModel> phases;
  final int order; // sequential order within a course

  const LessonModel({
    required this.id,
    required this.title,
    required this.videoPath,
    required this.transcription,
    required this.phases,
    required this.order,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) => LessonModel(
        id: json['id'] as String,
        title: json['title'] as String,
        videoPath: json['videoPath'] as String? ?? '',
        transcription: json['transcription'] as String? ?? '',
        phases: (json['phases'] as List)
            .map((p) => PhaseModel.fromJson(p as Map<String, dynamic>))
            .toList(),
        order: json['order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'videoPath': videoPath,
        'transcription': transcription,
        'phases': phases.map((p) => p.toJson()).toList(),
        'order': order,
      };

  LessonModel copyWith({
    String? id,
    String? title,
    String? videoPath,
    String? transcription,
    List<PhaseModel>? phases,
    int? order,
  }) =>
      LessonModel(
        id: id ?? this.id,
        title: title ?? this.title,
        videoPath: videoPath ?? this.videoPath,
        transcription: transcription ?? this.transcription,
        phases: phases ?? this.phases,
        order: order ?? this.order,
      );
}
