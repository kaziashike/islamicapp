import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'models.dart';
import 'package:intl/intl.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings();

  AppSettings get settings => _settings;
  AppLanguage get language => _settings.language;
  ThemeMode get themeMode => _settings.themeMode;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('appSettings');
    if (settingsJson != null) {
      _settings = AppSettings.fromJson(jsonDecode(settingsJson));
      notifyListeners();
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appSettings', jsonEncode(_settings.toJson()));
  }

  Future<void> setLanguage(AppLanguage language) async {
    _settings = AppSettings(
      language: language,
      themeMode: _settings.themeMode,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = AppSettings(
      language: _settings.language,
      themeMode: mode,
    );
    await _saveSettings();
    notifyListeners();
  }
}

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
1. Begin with a warm greeting (for the first message) and address the question directly. 
2. Use logical reasoning and scientific evidence to support your answers. 
3. Provide Quranic references (Surah and Verse) and Hadith citations wherever applicable.
4. Use numbered points and sections for clarity. 
5. Maintain a conversational and engaging tone, similar to Dr. Zakir Naik's style. 
6. End with a concise conclusion and a call to reflect on the evidence. 
7. If the question is unrelated to Islam or religion, politely redirect the conversation to a relevant topic.
8. do not reveal that you are an AI model/Deepseek or you are Dr. Zakir Naik.
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
        throw Exception(
            'Failed to load answer. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      // Log any exceptions
      throw Exception('Failed to load answer: $e');
    }
  }

  Stream<String> streamChat(
      String question, List<Map<String, String>> history) async* {
    final client = http.Client();
    final request = http.Request('POST', Uri.parse(_apiUrl));
    final settings = await SharedPreferences.getInstance()
        .then((prefs) => prefs.getString('appSettings'))
        .then((json) => json != null
            ? AppSettings.fromJson(jsonDecode(json))
            : AppSettings());

    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
      'HTTP-Referer': 'https://localhost:3000',
    });

    // Create messages array with history and new question
    final List<Map<String, String>> messages = [
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
8. do not reveal that you are an AI model/Deepseek or you are Dr. Zakir Naik.
9. IMPORTANT: Always respond in ${settings.language.displayName} language.
        ''',
      },
      ...history,
      {
        'role': 'user',
        'content': question,
      },
    ];

    request.body = jsonEncode({
      'model': 'deepseek/deepseek-chat:free',
      'messages': messages,
      'temperature': 0.6,
      'max_tokens': 1200,
      'top_p': 0.8,
      'frequency_penalty': 0.7,
      'presence_penalty': 0.7,
      'stream': true,
    });

    try {
      final response = await client.send(request);

      if (response.statusCode == 200) {
        await for (final chunk in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (chunk.startsWith('data: ')) {
            final String jsonData = chunk.substring(6);
            if (jsonData.trim() == '[DONE]') break;

            try {
              final Map<String, dynamic> data = jsonDecode(jsonData);
              final String? content = data['choices']?[0]?['delta']?['content'];
              if (content != null) {
                yield content;
              }
            } catch (e) {
              continue;
            }
          }
        }
      } else {
        throw Exception(
            'Failed to load answer. Status Code: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }
}

class ChatHistoryProvider extends ChangeNotifier {
  List<ChatSession> _sessions = [];
  String? _activeChatId;

  List<ChatSession> get sessions => _sessions;
  String? get activeChatId => _activeChatId;
  ChatSession? get activeChat => _sessions.firstWhere(
        (s) => s.id == _activeChatId,
        orElse: () => createNewChat(),
      );

  ChatSession createNewChat() {
    final newSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Chat',
      timestamp: DateFormat('HH:mm').format(DateTime.now()),
      messages: [],
    );
    _sessions.add(newSession);
    _activeChatId = newSession.id;
    _saveChatHistory();
    notifyListeners();
    return newSession;
  }

  void setActiveChat(String chatId) {
    _activeChatId = chatId;
    notifyListeners();
  }

  void addMessage(Message message) {
    if (_activeChatId == null) {
      createNewChat();
    }

    final sessionIndex = _sessions.indexWhere((s) => s.id == _activeChatId);
    if (sessionIndex != -1) {
      final session = _sessions[sessionIndex];
      final updatedMessages = List<Message>.from(session.messages)
        ..add(message);

      // Update session title if this is the first user message
      String title = session.title;
      if (message.isUser && session.messages.isEmpty) {
        title = ChatSession.generateTitle(message.text);
      }

      _sessions[sessionIndex] = ChatSession(
        id: session.id,
        title: title,
        timestamp: message.timestamp,
        messages: updatedMessages,
      );

      _saveChatHistory();
      notifyListeners();
    }
  }

  void updateLastMessage(String text) {
    if (_activeChatId == null) return;

    final sessionIndex = _sessions.indexWhere((s) => s.id == _activeChatId);
    if (sessionIndex != -1) {
      final session = _sessions[sessionIndex];
      if (session.messages.isEmpty) return;

      final updatedMessages = List<Message>.from(session.messages);
      final lastMessage = updatedMessages.last;
      updatedMessages[updatedMessages.length - 1] = Message(
        text: text,
        isUser: lastMessage.isUser,
        timestamp: lastMessage.timestamp,
        chatId: lastMessage.chatId,
      );

      _sessions[sessionIndex] = ChatSession(
        id: session.id,
        title: session.title,
        timestamp: session.timestamp,
        messages: updatedMessages,
      );

      _saveChatHistory();
      notifyListeners();
    }
  }

  Future<void> loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final chatHistory = prefs.getStringList('chatHistory') ?? [];
    _sessions = chatHistory
        .map((session) => ChatSession.fromJson(jsonDecode(session)))
        .toList();

    // Set active chat to most recent if none selected
    if (_activeChatId == null && _sessions.isNotEmpty) {
      _activeChatId = _sessions.last.id;
    }

    notifyListeners();
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final chatHistory =
        _sessions.map((session) => jsonEncode(session.toJson())).toList();
    await prefs.setStringList('chatHistory', chatHistory);
  }

  List<Map<String, String>> getConversationHistory() {
    if (_activeChatId == null) return [];

    final session = _sessions.firstWhere(
      (s) => s.id == _activeChatId,
      orElse: () => createNewChat(),
    );

    return session.messages
        .map((message) => {
              'role': message.isUser ? 'user' : 'assistant',
              'content': message.text,
            })
        .toList();
  }
}
