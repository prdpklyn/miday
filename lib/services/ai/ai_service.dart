import 'package:flutter_gemma/flutter_gemma.dart';

/// Result containing both function call and conversation details
class SmartQueryResult {
  final String? functionJson;
  final String? conversationalIntent;
  final bool isQuery;
  final bool isAction;

  SmartQueryResult({
    this.functionJson,
    this.conversationalIntent,
    this.isQuery = false,
    this.isAction = false,
  });

  bool get needsFunctionExecution => functionJson != null && (isAction || isQuery);
}

class AIService {
  bool _isInitialized = false;
  bool _isInitializing = false;
  InferenceModel? _model;
  String? _lastError;

  // Debug getter
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

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

    // Step 3: Use LLM for action classification
    final functionJson = await processQuery(query);
    if (functionJson != null) {
      return SmartQueryResult(
        functionJson: functionJson,
        isAction: true,
      );
    }

    // Step 4: Fallback - treat as unknown intent
    return SmartQueryResult(conversationalIntent: 'unknown');
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
