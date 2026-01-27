import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/services/ai/chat_service.dart';
import 'package:my_day/services/ai/ai_service.dart';
import 'package:my_day/services/ai/function_handler.dart';
import 'package:my_day/services/ai/navigation_handler.dart';
import 'package:my_day/presentation/providers/data_providers.dart';

// Chat Service Provider
final chatServiceProvider = Provider((ref) => ChatService());

// AI Service Provider
final aiServiceProvider = Provider((ref) => AIService());

// Navigation Handler Provider
final navigationHandlerProvider = Provider((ref) => NavigationHandler());

// Chat State
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isOpen;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isOpen = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isOpen,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isOpen: isOpen ?? this.isOpen,
      error: error,
    );
  }
}

// Chat Provider using AsyncNotifierProvider (works with mutable state in Riverpod 3.x)
final chatProvider = AsyncNotifierProvider<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});

class ChatNotifier extends AsyncNotifier<ChatState> {
  late final ChatService _chatService;
  late final AIService _aiService;
  late final NavigationHandler _navigationHandler;
  late final FunctionHandler _functionHandler;

  @override
  Future<ChatState> build() async {
    _chatService = ref.watch(chatServiceProvider);
    _aiService = ref.watch(aiServiceProvider);
    _navigationHandler = ref.watch(navigationHandlerProvider);
    _functionHandler = FunctionHandler(ref.watch(databaseHelperProvider));
    return ChatState();
  }

  void openChat() {
    state = AsyncValue.data(state.requireValue.copyWith(isOpen: true));
  }

  void closeChat() {
    state = AsyncValue.data(state.requireValue.copyWith(isOpen: false));
  }

  void toggleChat() {
    final current = state.requireValue;
    state = AsyncValue.data(current.copyWith(isOpen: !current.isOpen));
  }

  Future<void> sendMessage(String text, {Function()? onNavigationIntent}) async {
    if (text.trim().isEmpty) return;

    // Add user message
    _chatService.addUserMessage(text);
    state = AsyncValue.data(ChatState(
      messages: _chatService.messages,
      isLoading: true,
    ));

    try {
      // Check for navigation intent first
      if (_navigationHandler.hasNavigationIntent(text)) {
        final destination = _navigationHandler.extractDestination(text);
        if (destination != null) {
          _chatService.addAIMessage('Opening $destination...');
          state = AsyncValue.data(ChatState(
            messages: _chatService.messages,
            isLoading: false,
          ));
          onNavigationIntent?.call();
          return;
        }
      }

      // Process query with AI
      final response = await _aiService.processQuery(text);

      if (response != null) {
        // Execute function if returned
        await _functionHandler.handleExecution(response);
        
        // Refresh providers
        ref.invalidate(tasksProvider);
        ref.invalidate(eventsProvider);
        ref.invalidate(notesProvider);
        
        // Add success message
        _chatService.addAIMessage('Done! I\'ve processed your request.');
        state = AsyncValue.data(ChatState(
          messages: _chatService.messages,
          isLoading: false,
        ));
      } else {
        _chatService.addAIMessage(
          'I couldn\'t understand that. Try commands like:\n'
          '• "Add a task to call mom"\n'
          '• "Schedule meeting tomorrow at 2pm"\n'
          '• "Take a note about the project"'
        );
        state = AsyncValue.data(ChatState(
          messages: _chatService.messages,
          isLoading: false,
        ));
      }
    } catch (e) {
      _chatService.addAIMessage('Sorry, I encountered an error: ${e.toString()}');
      state = AsyncValue.data(ChatState(
        messages: _chatService.messages,
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  void clearHistory() {
    _chatService.clearHistory();
    state = AsyncValue.data(ChatState());
  }
}
