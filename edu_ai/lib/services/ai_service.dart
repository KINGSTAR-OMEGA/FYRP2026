/// Placeholder AI service.
/// Replace the methods here with real API calls (e.g., Claude / OpenAI) later.
class AiService {
  // Simulate network delay
  Future<String> ask({
    required String question,
    required String transcription,
    required List<Map<String, String>> history,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));

    final q = question.toLowerCase();

    if (q.contains('summar') || q.contains('overview')) {
      return 'Here is a summary based on the lesson content:\n\n'
          'The video covers the following key points from the transcription:\n\n'
          '• ${_firstSentence(transcription)}\n\n'
          'The content builds from foundational concepts toward more advanced ideas. '
          'Let me know if you would like me to elaborate on any specific section.';
    }

    if (q.contains('explain') || q.contains('what is') || q.contains('what are')) {
      return 'Great question! Based on the lesson transcription, here\'s an explanation:\n\n'
          'The material mentions: "${_excerpt(transcription)}"\n\n'
          'This concept is important because it forms the basis for later topics in the course. '
          'Do you want me to break it down further or give you an example?';
    }

    if (q.contains('example') || q.contains('demonstrate')) {
      return 'Sure! Here is a practical example related to what was covered in the video:\n\n'
          'Based on the content, you can think of it like this — imagine a real-world scenario '
          'where you apply the concept discussed. The transcription references: '
          '"${_excerpt(transcription)}"\n\n'
          'Would you like more examples or a different angle on this topic?';
    }

    // Default response
    return 'Thanks for your question! Based on the lesson transcription and video content, '
        'I can see you\'re asking about this topic. '
        'The relevant part of the lesson states: "${_excerpt(transcription)}"\n\n'
        'I\'m here to help you understand this material better. '
        'Feel free to ask me to explain, summarize, or give examples of any part of the lesson.';
  }

  Future<List<String>> generateQuestions({
    required String transcription,
    required String phaseTitle,
    int count = 2,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    // Placeholder - returns generic questions based on the phase title
    return List.generate(count, (i) =>
        'Question ${i + 1} about "$phaseTitle": What is the main concept covered in this section?');
  }

  String _firstSentence(String text) {
    if (text.isEmpty) return 'the lesson content';
    final end = text.indexOf(RegExp(r'[.!?]'));
    if (end == -1) return text.substring(0, text.length.clamp(0, 80));
    return text.substring(0, end + 1);
  }

  String _excerpt(String text) {
    if (text.isEmpty) return 'the lesson content';
    final start = (text.length * 0.2).toInt().clamp(0, text.length - 1);
    final end = (start + 120).clamp(0, text.length);
    return '${text.substring(start, end)}...';
  }
}
