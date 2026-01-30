import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

/// Service for speech-to-text using local Whisper model.
/// Provides on-device transcription without cloud dependencies.
class WhisperService {
  Whisper? _whisper;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _lastError;

  // Use tiny.en model for faster transcription (~40MB)
  // Alternatives: base.en (~140MB), small.en (~460MB)
  static const String _modelFileName = 'ggml-tiny.en.bin';

  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isInitialized && _whisper != null;
  String? get lastError => _lastError;

  /// Initialize the Whisper model
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    if (_isInitializing) {
      // Wait for ongoing initialization
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isInitialized;
    }

    _isInitializing = true;

    try {
      // Get the model file path
      final modelPath = await _getModelPath();

      // Check if model exists, if not, copy from assets
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        print('Whisper model not found, copying from assets...');
        await _copyModelFromAssets(modelPath);
      }

      // Initialize Whisper with the model
      _whisper = Whisper(
        model: WhisperModel.tiny, // tiny.en model
        downloadHost: '', // We're using local model, not downloading
      );

      _isInitialized = true;
      _lastError = null;
      print('Whisper Service initialized successfully');
      return true;
    } catch (e, stack) {
      _lastError = e.toString();
      print('Failed to initialize Whisper: $e');
      print(stack);
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Transcribe audio file to text
  Future<String?> transcribe(String audioPath) async {
    if (!_isInitialized || _whisper == null) {
      final initialized = await initialize();
      if (!initialized) {
        return null;
      }
    }

    try {
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        _lastError = 'Audio file not found: $audioPath';
        return null;
      }

      print('Transcribing audio: $audioPath');

      // Transcribe the audio
      final result = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          isTranslate: false,
          isNoTimestamps: true,
          splitOnWord: true,
        ),
      );

      final transcription = result.text.trim();
      print('Transcription result: $transcription');
      return transcription.isNotEmpty ? transcription : null;
    } catch (e, stack) {
      _lastError = e.toString();
      print('Transcription error: $e');
      print(stack);
      return null;
    }
  }

  /// Get the path where the model should be stored
  Future<String> _getModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/whisper_models/$_modelFileName';
  }

  /// Copy the Whisper model from assets to documents directory
  Future<void> _copyModelFromAssets(String destinationPath) async {
    try {
      // Create directory if needed
      final dir = Directory(destinationPath).parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Load from assets and write to file
      final byteData = await rootBundle.load('assets/models/$_modelFileName');
      final buffer = byteData.buffer;
      final file = File(destinationPath);
      await file.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
      print('Whisper model copied to: $destinationPath');
    } catch (e) {
      // Model might not be bundled, Whisper will download it
      print('Could not copy model from assets (will download): $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _whisper = null;
    _isInitialized = false;
  }
}
