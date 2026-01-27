import 'package:my_day/services/ai/ai_service.dart';

class AutoTagger {
  final AIService _aiService;

  AutoTagger(this._aiService);

  /// Suggest tags for a note based on its content
  Future<List<String>> suggestTags(String noteContent) async {
    final prompt = '''
Analyze this note and suggest 2-3 relevant hashtags (single words, no spaces).

Note: "$noteContent"

Reply ONLY with comma-separated tags, for example: work,meeting,urgent
''';

    try {
      final response = await _aiService.processRawQuery(prompt);
      if (response == null || response.isEmpty) {
        return [];
      }

      // Parse comma-separated tags
      final tags = response
          .split(',')
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty && !tag.contains(' '))
          .take(3)
          .toList();

      return tags;
    } catch (e) {
      return [];
    }
  }
}
