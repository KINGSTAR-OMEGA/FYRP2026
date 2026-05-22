import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  // Groq API Key
  static String get grokApiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String grokBaseUrl = 'https://api.groq.com/openai/v1';
  static const String grokChatModel = 'llama-3.3-70b-versatile';

  // SharedPreferences key prefixes
  static const String memoryKeyPrefix = 'student_memory_v1_';
  static const String aiQuestionsKeyPrefix = 'ai_questions_v1_';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
}
