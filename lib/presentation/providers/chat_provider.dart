import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/services/ai/chat_service.dart';
import 'package:my_day/services/ai/ai_service.dart';
import 'package:my_day/services/ai/function_handler.dart';
import 'package:my_day/services/ai/navigation_handler.dart';
import 'package:my_day/services/ai/response_generator.dart';
import 'package:my_day/presentation/providers/data_providers.dart';

// Chat Service Provider
final chatServiceProvider = Provider((ref) => ChatService());

// AI Service Provider
final aiServiceProvider = Provider((ref) => AIService());

// Navigation Handler Provider
final navigationHandlerProvider = Provider((ref) => NavigationHandler());

// Response Generator Provider
final responseGeneratorProvider = Provider((ref) => ResponseGenerator());

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
  late final ResponseGenerator _responseGenerator;

  @override
  Future<ChatState> build() async {
    _chatService = ref.watch(chatServiceProvider);
    _aiService = ref.watch(aiServiceProvider);
    _navigationHandler = ref.watch(navigationHandlerProvider);
    _functionHandler = FunctionHandler(ref.watch(databaseHelperProvider));
    _responseGenerator = ref.watch(responseGeneratorProvider);
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

  Future<void> sendMessage(String text, {void Function(String destination)? onNavigationIntent}) async {
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
          onNavigationIntent?.call(destination);
          return;
        }
      }

      // Process with smart query (includes intent classification)
      final context = _chatService.getConversationContext();
      final result = await _aiService.processSmartQuery(text, conversationContext: context);

      // Handle conversational intents (no function execution needed)
      if (result.conversationalIntent != null && !result.needsFunctionExecution) {
        final response = _responseGenerator.conversationalResponse(result.conversationalIntent!);
        _chatService.addAIMessage(response);
        state = AsyncValue.data(ChatState(
          messages: _chatService.messages,
          isLoading: false,
        ));
        return;
      }

      // Handle function execution (actions or queries)
      if (result.needsFunctionExecution && result.functionJson != null) {
        final funcResult = await _functionHandler.handleExecution(result.functionJson!);
        
        // Refresh providers for data changes
        ref.invalidate(tasksProvider);
        ref.invalidate(eventsProvider);
        ref.invalidate(notesProvider);
        
        // Generate natural response based on function result
        final response = _generateResponseForResult(funcResult);
        _chatService.addAIMessage(response);
        state = AsyncValue.data(ChatState(
          messages: _chatService.messages,
          isLoading: false,
        ));
        return;
      }

      // Fallback for unrecognized input
      _chatService.addAIMessage(_responseGenerator.conversationalResponse('unknown'));
      state = AsyncValue.data(ChatState(
        messages: _chatService.messages,
        isLoading: false,
      ));

    } catch (e) {
      _chatService.addAIMessage(_responseGenerator.errorResponse());
      state = AsyncValue.data(ChatState(
        messages: _chatService.messages,
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  /// Generate natural language response based on function execution result
  String _generateResponseForResult(FunctionResult result) {
    if (!result.success) {
      return _responseGenerator.errorResponse(result.error);
    }

    switch (result.functionName) {
      case 'create_task':
        return _responseGenerator.taskCreated(
          title: result.data['title'] ?? 'Task',
          priority: result.data['priority'],
          dueDate: result.data['dueDate'] != null 
              ? DateTime.tryParse(result.data['dueDate']) 
              : null,
        );

      case 'create_event':
        return _responseGenerator.eventCreated(
          title: result.data['title'] ?? 'Event',
          startTime: result.data['startTime'] != null 
              ? DateTime.tryParse(result.data['startTime']) ?? DateTime.now()
              : DateTime.now(),
          durationMinutes: result.data['durationMinutes'],
        );

      case 'create_note':
        return _responseGenerator.noteCreated(
          title: result.data['title'] ?? 'Note',
          tags: (result.data['tags'] as List<dynamic>?)?.cast<String>(),
        );

      case 'get_tasks':
        return _responseGenerator.tasksSummary(
          total: result.data['total'] ?? 0,
          completed: result.data['completed'] ?? 0,
          highPriority: result.data['highPriority'] ?? 0,
          topTasks: (result.data['topTasks'] as List<dynamic>?)?.cast<String>(),
        );

      case 'get_events':
        final nextTime = result.data['nextEventTime'] != null
            ? DateTime.tryParse(result.data['nextEventTime'])
            : null;
        return _responseGenerator.scheduleSummary(
          eventCount: result.data['todayCount'] ?? 0,
          taskCount: 0,
          nextEvent: result.data['nextEvent'],
          nextEventTime: nextTime != null ? _formatTime(nextTime) : null,
        );

      case 'get_schedule':
        final tasks = result.data['tasks'] as Map<String, dynamic>? ?? {};
        final events = result.data['events'] as Map<String, dynamic>? ?? {};
        final nextTime = events['nextEventTime'] != null
            ? DateTime.tryParse(events['nextEventTime'])
            : null;
        return _responseGenerator.scheduleSummary(
          eventCount: events['todayCount'] ?? 0,
          taskCount: tasks['pending'] ?? 0,
          nextEvent: events['nextEvent'],
          nextEventTime: nextTime != null ? _formatTime(nextTime) : null,
        );

      default:
        return "Done! I've processed your request.";
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    if (minute == 0) {
      return '$displayHour $period';
    }
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  void clearHistory() {
    _chatService.clearHistory();
    state = AsyncValue.data(ChatState());
  }
}
