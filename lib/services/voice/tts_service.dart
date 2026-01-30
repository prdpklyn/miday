import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

/// Service for text-to-speech using native platform TTS.
/// Speaks AI responses aloud when voice mode is enabled.
class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String? _lastError;

  // TTS settings
  double _speechRate = 0.5; // 0.0 to 1.0
  double _pitch = 1.0; // 0.5 to 2.0
  double _volume = 1.0; // 0.0 to 1.0

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  String? get lastError => _lastError;

  /// Initialize the TTS engine
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Configure for iOS
      if (Platform.isIOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }

      // Set default parameters
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(_volume);

      // Set language to US English
      await _tts.setLanguage('en-US');

      // Set up completion handler
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      // Set up error handler
      _tts.setErrorHandler((message) {
        _lastError = message;
        _isSpeaking = false;
        print('TTS Error: $message');
      });

      // Set up start handler
      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      // Set up cancel handler
      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });

      _isInitialized = true;
      _lastError = null;
      print('TTS Service initialized successfully');
      return true;
    } catch (e, stack) {
      _lastError = e.toString();
      print('Failed to initialize TTS: $e');
      print(stack);
      return false;
    }
  }

  /// Speak the given text
  Future<bool> speak(String text) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (text.trim().isEmpty) return false;

    try {
      // Stop any current speech first
      if (_isSpeaking) {
        await stop();
      }

      // Clean the text for better speech
      final cleanedText = _cleanTextForSpeech(text);

      final result = await _tts.speak(cleanedText);
      return result == 1;
    } catch (e) {
      _lastError = e.toString();
      print('TTS speak error: $e');
      return false;
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      print('TTS stop error: $e');
    }
  }

  /// Pause speaking (iOS only)
  Future<void> pause() async {
    if (Platform.isIOS) {
      try {
        await _tts.pause();
      } catch (e) {
        print('TTS pause error: $e');
      }
    }
  }

  /// Set speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    if (_isInitialized) {
      await _tts.setSpeechRate(_speechRate);
    }
  }

  /// Set pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    if (_isInitialized) {
      await _tts.setPitch(_pitch);
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_isInitialized) {
      await _tts.setVolume(_volume);
    }
  }

  /// Get available voices
  Future<List<dynamic>> getVoices() async {
    if (!_isInitialized) await initialize();
    return await _tts.getVoices ?? [];
  }

  /// Get available languages
  Future<List<dynamic>> getLanguages() async {
    if (!_isInitialized) await initialize();
    return await _tts.getLanguages ?? [];
  }

  /// Clean text for better speech output
  String _cleanTextForSpeech(String text) {
    var cleaned = text;

    // Remove emojis (they cause weird pauses)
    cleaned = cleaned.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}]', unicode: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\u{1F300}-\u{1F5FF}]', unicode: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\u{1F680}-\u{1F6FF}]', unicode: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\u{2600}-\u{26FF}]', unicode: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\u{2700}-\u{27BF}]', unicode: true), '');

    // Replace common symbols
    cleaned = cleaned.replaceAll('&', ' and ');
    cleaned = cleaned.replaceAll('@', ' at ');

    // Clean up multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }

  /// Dispose resources
  void dispose() {
    _tts.stop();
    _isInitialized = false;
    _isSpeaking = false;
  }
}
