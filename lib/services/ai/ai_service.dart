import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:my_day/services/ai/conversation_manager.dart';

/// Result containing both function call and conversation details
class SmartQueryResult {
  final String? functionJson;
  final String? conversationalIntent;
  final String? conversationalResponse; // Actual LLM response for conversation
  final bool isQuery;
  final bool isAction;
  final bool isConversation;

  SmartQueryResult({
    this.functionJson,
    this.conversationalIntent,
    this.conversationalResponse,
    this.isQuery = false,
    this.isAction = false,
    this.isConversation = false,
  });

  bool get needsFunctionExecution => functionJson != null && (isAction || isQuery);
  bool get hasConversationalResponse => conversationalResponse != null && conversationalResponse!.isNotEmpty;
}

class AIService {
  bool _isInitialized = false;
  bool _isInitializing = false;
  InferenceModel? _model;
  String? _lastError;

  // Conversation manager for persistent context
  final ConversationManager _conversationManager = ConversationManager();

  // Debug getter
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  ConversationManager get conversationManager => _conversationManager;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    
    _isInitializing = true;
    
    try {
      // Load model from local assets (bundled with app)
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromAsset('assets/models/gemma3-1b-it-int4.task').install();
      
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 4096,
        preferredBackend: PreferredBackend.gpu,
      );
      
      _isInitialized = true;
      _lastError = null;
      print("✅ AI Service Initialized successfully");
    } catch (e, stack) {
      _lastError = e.toString();
      print("❌ AI Service Initialization Failed: $e");
      print(stack);
    } finally {
      _isInitializing = false;
    }
  }

  /// Enhanced query processing with context awareness
  Future<SmartQueryResult> processSmartQuery(String query, {String? conversationContext}) async {
    // Step 1: Check for simple conversational intents first (no LLM needed)
    final conversationalIntent = _detectConversationalIntent(query);
    if (conversationalIntent != null) {
      return SmartQueryResult(conversationalIntent: conversationalIntent);
    }

    // Step 2: Check for query intents (asking about schedule, tasks, etc.)
    final queryIntent = _detectQueryIntent(query);
    if (queryIntent != null) {
      return SmartQueryResult(
        functionJson: queryIntent,
        isQuery: true,
      );
    }

    // Step 3: Use LLM with conversation context for intelligent response
    // This now handles BOTH function calls AND conversational responses
    final result = await processConversationalQuery(query, conversationContext: conversationContext);
    return result;
  }

  /// Process query with full conversation context - returns function OR conversation
  Future<SmartQueryResult> processConversationalQuery(String query, {String? conversationContext}) async {
    // Ensure initialization
    if (!_isInitialized || _model == null) {
      await initialize();
      if (!_isInitialized || _model == null) {
        return SmartQueryResult(conversationalIntent: 'unknown');
      }
    }

    // Build the conversation-aware prompt
    final now = DateTime.now();
    final dayName = _weekdayName(now.weekday);

    // Include conversation history if available
    final historySection = (conversationContext != null && conversationContext.isNotEmpty)
        ? '''
Previous conversation:
$conversationContext

'''
        : '';

    final prompt = '''SYSTEM: You are a helpful personal assistant for a day planning app called "My Day".

Current Time: $dayName, ${now.toIso8601String()}

$historySection
Available Functions (use ONLY when the user wants to create something):
- create_task: {"name": "create_task", "arguments": {"title": string, "priority": "high"|"medium"|"low", "due_date": ISO-8601 or null}}
- create_event: {"name": "create_event", "arguments": {"title": string, "start_time": ISO-8601, "duration_minutes": int}}
- create_note: {"name": "create_note", "arguments": {"title": string, "content": string, "tags": string[]}}

Time References:
- "tomorrow" -> ${now.add(const Duration(days: 1)).toIso8601String().split('T')[0]}
- "next week" -> ${now.add(const Duration(days: 7)).toIso8601String().split('T')[0]}

Instructions:
1. If the user is asking you to CREATE a task, event, or note -> respond with ONLY the JSON function call
2. If the user is having a conversation, asking questions, or chatting -> respond naturally as a friendly assistant
3. If the user references something from the conversation history, use that context
4. Keep responses concise and helpful

User: $query

Response:''';

    InferenceChat? chat;

    try {
      chat = await _model!.createChat();

      await chat.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));

      final StringBuffer fullResponse = StringBuffer();

      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          fullResponse.write(response.token);
        } else if (response is FunctionCallResponse) {
          final funcJson = '{"name": "${response.name}", "arguments": ${response.args}}';
          print("🤖 AI Function Call (Native): $funcJson");
          return SmartQueryResult(functionJson: funcJson, isAction: true);
        }
      }

      final responseText = fullResponse.toString().trim();
      print("🤖 AI Response: $responseText");

      // Check if response contains a function call
      final functionJson = _extractFunctionCall(responseText);
      if (functionJson != null) {
        return SmartQueryResult(functionJson: functionJson, isAction: true);
      }

      // Otherwise, it's a conversational response
      final cleanedResponse = _cleanConversationalResponse(responseText);
      if (cleanedResponse.isNotEmpty) {
        return SmartQueryResult(
          conversationalResponse: cleanedResponse,
          isConversation: true,
        );
      }

      // Fallback
      return SmartQueryResult(conversationalIntent: 'unknown');

    } catch (e, stack) {
      print("❌ Error in conversational query: $e");
      print(stack);
      return SmartQueryResult(conversationalIntent: 'unknown');
    }
  }

  /// Clean up LLM response for display
  String _cleanConversationalResponse(String response) {
    var cleaned = response.trim();

    // Remove any "Assistant:" prefix the model might add
    if (cleaned.toLowerCase().startsWith('assistant:')) {
      cleaned = cleaned.substring(10).trim();
    }

    // Remove markdown artifacts
    cleaned = cleaned.replaceAll(RegExp(r'```\w*\n?'), '');

    return cleaned;
  }

  /// Detect simple conversational patterns without LLM
  String? _detectConversationalIntent(String query) {
    final lower = query.toLowerCase().trim();
    
    // Greetings
    if (RegExp(r'^(hi|hello|hey|good morning|good afternoon|good evening)[\s!.]*$').hasMatch(lower)) {
      return 'hello';
    }
    
    // Thanks
    if (RegExp(r'^(thanks|thank you|thx|ty|cheers)[\s!.]*$').hasMatch(lower)) {
      return 'thanks';
    }
    
    // Help
    if (RegExp(r'^(help|what can you do|how do you work)[\s?]*$').hasMatch(lower)) {
      return 'help';
    }
    
    // Yes/No confirmations
    if (RegExp(r'^(yes|yeah|yep|sure|ok|okay)[\s!.]*$').hasMatch(lower)) {
      return 'yes';
    }
    if (RegExp(r'^(no|nope|nah|cancel)[\s!.]*$').hasMatch(lower)) {
      return 'no';
    }

    return null;
  }

  /// Detect query intents (user asking for information)
  String? _detectQueryIntent(String query) {
    final lower = query.toLowerCase().trim();
    
    // Schedule queries
    if (RegExp(r"(what('s| is| do i have)|show|list|my).*(today|schedule|calendar|planned|upcoming)", caseSensitive: false).hasMatch(lower)) {
      return '{"name": "get_schedule", "arguments": {}}';
    }
    
    // Task queries
    if (RegExp(r"(what|show|list|how many).*(task|to.?do|pending|todo)", caseSensitive: false).hasMatch(lower)) {
      return '{"name": "get_tasks", "arguments": {"filter": "pending"}}';
    }

    // Event queries
    if (RegExp(r"(what|show|list).*(event|meeting|appointment)", caseSensitive: false).hasMatch(lower)) {
      return '{"name": "get_events", "arguments": {}}';
    }

    return null;
  }

  /// Original function for LLM-based action parsing
  Future<String?> processQuery(String query) async {
    // Step 1: Ensure initialization
    if (!_isInitialized || _model == null) {
      await initialize();
      
      if (!_isInitialized || _model == null) {
        return null;
      }
    }

    // Step 2: Build the prompt with enhanced time parsing
    final now = DateTime.now();
    final dayName = _weekdayName(now.weekday);
    final prompt = '''SYSTEM: You are a strict JSON-only function calling assistant.
Current Time: $dayName, ${now.toIso8601String()}

Available Functions:
- create_task(title: string, priority: "high"|"medium"|"low", due_date: ISO-8601 string or null): Create a todo task
- create_event(title: string, start_time: ISO-8601 string, duration_minutes: int): Schedule an event
- create_note(title: string, content: string, tags: string[]): Save a note

Rules:
1. Analyze the user request.
2. If it matches a function, output ONLY JSON.
3. Do NOT add explanation, conversation, or markdown.
4. If no function matches, return an empty string.

Time Reference:
- "tomorrow" -> ${now.add(const Duration(days: 1)).toIso8601String().split('T')[0]}
- "next week" -> ${now.add(const Duration(days: 7)).toIso8601String().split('T')[0]}

User Request: "$query"

Response (JSON ONLY):''';
    
    // Step 3: Create chat and send message
    InferenceChat? chat;
    
    try {
      chat = await _model!.createChat();
      
      await chat.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));
      
      // Step 5: Generate response using STREAMING API
      final StringBuffer fullResponse = StringBuffer();
      
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          fullResponse.write(response.token);
        } else if (response is FunctionCallResponse) {
          // Some models might try to use tool use features if available
          final funcJson = '{"name": "${response.name}", "arguments": ${response.args}}';
          print("🤖 AI Function Call (Native): $funcJson");
          return funcJson;
        }
      }
      
      final responseText = fullResponse.toString();
      print("🤖 AI Raw Response: $responseText");
      
      // Step 6: Extract JSON
      return _extractFunctionCall(responseText);
      
    } catch (e, stack) {
      print("❌ Error processing query: $e");
      print(stack);
      return null;
    }
  }

  String? _extractFunctionCall(String response) {
    if (response.isEmpty) return null;
    
    var cleaned = response.trim();
    
    // Strip markdown code blocks if present
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      if (lines.length >= 2) {
        // Remove first and last lines (```json and ```)
        cleaned = lines.sublist(1, lines.length - 1).join('\n').trim();
      }
    }

    // Try to find JSON with nested braces
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    
    if (start != -1 && end != -1 && end > start) {
      final json = cleaned.substring(start, end + 1);
      
      // Validate it has required fields
      try {
         // Basic validation check
         if (json.contains('"name"') && json.contains('"arguments"')) {
           return json;
         }
      } catch (e) {
        print("⚠️ JSON validation warning: $e");
      }
    }
    
    return null;
  }

  /// Process a raw query without function calling (for auto-tagger, etc.)
  Future<String?> processRawQuery(String query) async {
    // Ensure initialization
    if (!_isInitialized || _model == null) {
      await initialize();
      
      if (!_isInitialized || _model == null) {
        return null;
      }
    }

    InferenceChat? chat;
    
    try {
      chat = await _model!.createChat();
      
      await chat.addQueryChunk(Message.text(
        text: query,
        isUser: true,
      ));
      
      final StringBuffer fullResponse = StringBuffer();
      
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          fullResponse.write(response.token);
        }
      }
      
      return fullResponse.toString().trim();
    } catch (e) {
      print("Error in processRawQuery: $e");
      return null;
    }
  }
  
  Future<void> dispose() async {
    if (_model != null) {
      _model = null;
      _isInitialized = false;
    }
  }

  String _weekdayName(int weekday) {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday];
  }
}
