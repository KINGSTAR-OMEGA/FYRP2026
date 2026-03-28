class ChatMessageModel {
  final String id;
  final String role; // 'user' | 'ai'
  final String content;
  final DateTime timestamp;

  const ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  bool get isUser => role == 'user';

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}
