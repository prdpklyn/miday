import 'package:flutter_gemma/flutter_gemma.dart';

/// Represents a single turn in the conversation
class ConversationTurn {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ConversationTurn({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

/// Manages persistent conversation context across multiple turns.
/// Maintains chat history and handles context window management.
class ConversationManager {
  InferenceChat? _persistentChat;
  final List<ConversationTurn> _history = [];

  /// Maximum number of conversation turns to keep in context
  static const int maxContextTurns = 6;

  /// Get the current conversation history
  List<ConversationTurn> get history => List.unmodifiable(_history);

  /// Check if a chat session is active
  bool get hasActiveChat => _persistentChat != null;

  /// Initialize or get the persistent chat session
  Future<InferenceChat> initializeChat(InferenceModel model) async {
    if (_persistentChat == null) {
      _persistentChat = await model.createChat();
    }
    return _persistentChat!;
  }

  /// Add a user message to the conversation history
  void addUserMessage(String text) {
    _history.add(ConversationTurn(
      role: 'user',
      content: text,
    ));
    _pruneHistoryIfNeeded();
  }

  /// Add an assistant message to the conversation history
  void addAssistantMessage(String text) {
    _history.add(ConversationTurn(
      role: 'assistant',
      content: text,
    ));
    _pruneHistoryIfNeeded();
  }

  /// Get formatted conversation history for LLM context
  String getFormattedHistory() {
    if (_history.isEmpty) return '';

    return _history
        .map((turn) => '${turn.isUser ? "User" : "Assistant"}: ${turn.content}')
        .join('\n');
  }

  /// Get the last N turns of conversation
  String getRecentHistory({int turns = 4}) {
    final recentTurns = _history.length > turns
        ? _history.sublist(_history.length - turns)
        : _history;

    return recentTurns
        .map((turn) => '${turn.isUser ? "User" : "Assistant"}: ${turn.content}')
        .join('\n');
  }

  /// Get the last assistant response (useful for context)
  String? getLastAssistantResponse() {
    for (var i = _history.length - 1; i >= 0; i--) {
      if (_history[i].isAssistant) {
        return _history[i].content;
      }
    }
    return null;
  }

  /// Get the last user message (useful for context)
  String? getLastUserMessage() {
    for (var i = _history.length - 1; i >= 0; i--) {
      if (_history[i].isUser) {
        return _history[i].content;
      }
    }
    return null;
  }

  /// Reset the conversation (clear history and chat session)
  Future<void> resetConversation() async {
    _history.clear();
    _persistentChat = null;
  }

  /// Prune old messages to stay within context window
  void _pruneHistoryIfNeeded() {
    // Keep only the last maxContextTurns * 2 messages (user + assistant pairs)
    final maxMessages = maxContextTurns * 2;
    if (_history.length > maxMessages) {
      _history.removeRange(0, _history.length - maxMessages);
    }
  }

  /// Get the number of turns in current conversation
  int get turnCount => (_history.length / 2).ceil();

  /// Check if conversation has any history
  bool get hasHistory => _history.isNotEmpty;
}
