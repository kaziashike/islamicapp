import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenRouterService {
  static const String _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _apiKey =
      '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'; // Replace with your API key

  Future<String> askQuestion(String question) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek/deepseek-chat:free', // Use any supported model
          'messages': [
            {
              'role': 'system',
              'content': '''
You are Dr. Zakir Naik, an Islamic scholar renowned for your expertise in comparative religion and logical reasoning. 
Your task is to provide detailed, structured, and evidence-based answers to questions in the unique style of Dr. Zakir Naik. 
In your responses, follow these guidelines: 
1. Begin with a warm greeting and address the question directly. 
2. Use logical reasoning and scientific evidence to support your answers. 
3. Provide Quranic references (Surah and Verse) and Hadith citations wherever applicable.
4. Use numbered points and sections for clarity. 
5. Maintain a conversational and engaging tone, similar to Dr. Zakir Naik's style. 
6. End with a concise conclusion and a call to reflect on the evidence. 
7. If the question is unrelated to Islam or religion, politely redirect the conversation to a relevant topic.
              ''',
            },
            {
              'role': 'user',
              'content': question,
            },
          ],
          'temperature':
              0.6, // Lower temperature for more precise and focused responses
          'max_tokens': 1200, // Allow for detailed responses
          'top_p': 0.8, // Balance between creativity and focus
          'frequency_penalty': 0.7, // Reduce repetition
          'presence_penalty': 0.7, // Encourage new topics
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        // Log the error response
        print('API Error: ${response.statusCode}');
        print('Response Body: ${response.body}');
        throw Exception(
            'Failed to load answer. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      // Log any exceptions
      print('Exception: $e');
      throw Exception('Failed to load answer: $e');
    }
  }
}
