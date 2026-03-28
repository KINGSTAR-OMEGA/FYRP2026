class QuestionModel {
  final String id;
  final String text;
  final List<String> options; // exactly 4 options
  final int correctIndex;
  final String explanation;

  const QuestionModel({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
        id: json['id'] as String,
        text: json['text'] as String,
        options: List<String>.from(json['options'] as List),
        correctIndex: json['correctIndex'] as int,
        explanation: json['explanation'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };

  QuestionModel copyWith({
    String? id,
    String? text,
    List<String>? options,
    int? correctIndex,
    String? explanation,
  }) =>
      QuestionModel(
        id: id ?? this.id,
        text: text ?? this.text,
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        explanation: explanation ?? this.explanation,
      );
}
