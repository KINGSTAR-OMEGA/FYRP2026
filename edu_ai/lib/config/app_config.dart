class AppConfig {
  AppConfig._();

  // Groq API Key. Provide this at build time using:
  // flutter run --dart-define=GROQ_API_KEY=your_key_here
  static const String grokApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String grokBaseUrl = 'https://api.groq.com/openai/v1';
  static const String grokChatModel = 'llama-3.3-70b-versatile';

  // SharedPreferences key prefixes
  static const String memoryKeyPrefix = 'student_memory_v1_';
  static const String aiQuestionsKeyPrefix = 'ai_questions_v1_';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
}
