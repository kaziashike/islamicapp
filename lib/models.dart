import 'package:flutter/material.dart' show ThemeMode;

class Message {
  final String text;
  final bool isUser;
  final String timestamp;
  final String chatId;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.chatId,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp,
        'chatId': chatId,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        text: json['text'],
        isUser: json['isUser'],
        timestamp: json['timestamp'],
        chatId: json['chatId'],
      );
}

enum AppLanguage {
  english,
  bangla,
  chinese;

  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.bangla:
        return 'বাংলা';
      case AppLanguage.chinese:
        return '中文';
    }
  }

  String get languageCode {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.bangla:
        return 'bn';
      case AppLanguage.chinese:
        return 'zh';
    }
  }
}

extension ThemeModeExtension on ThemeMode {
  String get displayName {
    switch (this) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System Theme';
    }
  }
}

class AppSettings {
  final AppLanguage language;
  final ThemeMode themeMode;

  AppSettings({
    this.language = AppLanguage.english,
    this.themeMode = ThemeMode.system,
  });

  Map<String, dynamic> toJson() => {
        'language': language.index,
        'themeMode': themeMode.index,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        language: AppLanguage.values[json['language'] ?? 0],
        themeMode: ThemeMode.values[json['themeMode'] ?? 2],
      );
}

class ChatSession {
  final String id;
  final String title;
  final String timestamp;
  final List<Message> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'timestamp': timestamp,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'],
        title: json['title'],
        timestamp: json['timestamp'],
        messages: (json['messages'] as List)
            .map((m) => Message.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  // Helper method to generate title from first message
  static String generateTitle(String firstMessage) {
    // Take first 30 characters or up to first newline
    String title = firstMessage.split('\n')[0];
    if (title.length > 30) {
      title = '${title.substring(0, 30)}...';
    }
    return title;
  }
}
