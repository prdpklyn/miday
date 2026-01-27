import 'package:flutter/material.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatService {
  final List<ChatMessage> _messages = [];
  
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void addMessage(ChatMessage message) {
    _messages.add(message);
  }

  void addUserMessage(String text) {
    _messages.add(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));
  }

  void addAIMessage(String text) {
    _messages.add(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void clearHistory() {
    _messages.clear();
  }

  String getConversationContext() {
    // Get last 5 messages for context
    final recentMessages = _messages.length > 5 
        ? _messages.sublist(_messages.length - 5) 
        : _messages;
    
    return recentMessages
        .map((m) => '${m.isUser ? "User" : "Assistant"}: ${m.text}')
        .join('\n');
  }
}
