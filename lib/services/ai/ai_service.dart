import 'package:flutter_gemma/flutter_gemma.dart';

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
        maxTokens: 1024,
        preferredBackend: PreferredBackend.gpu,
      );
      
      _isInitialized = true;
      _lastError = null;
      print("✅ AI Service Initialized successfully");
    } catch (e, stack) {
      _lastError = e.toString();
      print("❌ AI Service Initialized Failed: $e");
      print(stack);
    } finally {
      _isInitializing = false;
    }
  }

  Future<String?> processQuery(String query) async {
    // Step 1: Ensure initialization
    if (!_isInitialized || _model == null) {
      await initialize();
      
      if (!_isInitialized || _model == null) {
        return null;
      }
    }

    // Step 2: Build the prompt with enhanced time parsing
    final prompt = '''You are an AI assistant. Convert the user request to a JSON function call.

Functions:
- create_task(title, priority, due_date): priority is "high", "medium", or "low", due_date is ISO format or null
- create_event(title, start_time, duration_minutes): start_time is ISO format
- create_note(title, content, tags): tags is array of strings

Time parsing examples:
- "tomorrow" → tomorrow's date
- "next Tuesday" → next Tuesday's date
- "5pm" or "17:00" → time portion
- "in 2 hours" → current time + 2 hours

Request: "$query"

Reply with ONLY JSON like: {"name": "function_name", "arguments": {...}}

JSON:''';
    
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
          final funcJson = '{"name": "${response.name}", "arguments": ${response.args}}';
          return funcJson;
        }
      }
      
      final responseText = fullResponse.toString();
      
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
    
    // Try to find JSON with nested braces
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    
    if (start != -1 && end != -1 && end > start) {
      final json = response.substring(start, end + 1);
      
      // Validate it has required fields
      if (json.contains('"name"') && json.contains('"arguments"')) {
        return json;
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
}
