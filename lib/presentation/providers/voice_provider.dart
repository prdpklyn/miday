import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/services/voice/whisper_service.dart';
import 'package:my_day/services/voice/audio_recorder.dart';
import 'package:my_day/services/voice/tts_service.dart';

// Service providers
final whisperServiceProvider = Provider((ref) => WhisperService());
final audioRecorderProvider = Provider((ref) => AudioRecorderService());
final ttsServiceProvider = Provider((ref) => TTSService());

/// Voice state for the chat interface
class VoiceState {
  final bool isRecording;
  final bool isTranscribing;
  final bool isSpeaking;
  final bool isVoiceModeEnabled; // Auto-speak AI responses
  final String? transcribedText;
  final String? error;
  final double amplitude; // For recording visualization

  const VoiceState({
    this.isRecording = false,
    this.isTranscribing = false,
    this.isSpeaking = false,
    this.isVoiceModeEnabled = false,
    this.transcribedText,
    this.error,
    this.amplitude = 0.0,
  });

  VoiceState copyWith({
    bool? isRecording,
    bool? isTranscribing,
    bool? isSpeaking,
    bool? isVoiceModeEnabled,
    String? transcribedText,
    String? error,
    double? amplitude,
  }) {
    return VoiceState(
      isRecording: isRecording ?? this.isRecording,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isVoiceModeEnabled: isVoiceModeEnabled ?? this.isVoiceModeEnabled,
      transcribedText: transcribedText,
      error: error,
      amplitude: amplitude ?? this.amplitude,
    );
  }

  bool get isProcessing => isRecording || isTranscribing;
  bool get canStartRecording => !isRecording && !isTranscribing && !isSpeaking;
}

/// Provider for voice state management
final voiceProvider = AsyncNotifierProvider<VoiceNotifier, VoiceState>(() {
  return VoiceNotifier();
});

class VoiceNotifier extends AsyncNotifier<VoiceState> {
  late final WhisperService _whisperService;
  late final AudioRecorderService _audioRecorder;
  late final TTSService _ttsService;

  @override
  Future<VoiceState> build() async {
    _whisperService = ref.watch(whisperServiceProvider);
    _audioRecorder = ref.watch(audioRecorderProvider);
    _ttsService = ref.watch(ttsServiceProvider);

    // Initialize services in background
    _initializeServices();

    return const VoiceState();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize TTS first (faster)
      await _ttsService.initialize();

      // Initialize Whisper (may take longer due to model loading)
      await _whisperService.initialize();
    } catch (e) {
      print('Voice services initialization error: $e');
    }
  }

  /// Toggle recording on/off
  Future<void> toggleRecording() async {
    final currentState = state.requireValue;

    if (currentState.isRecording) {
      await stopRecording();
    } else {
      await startRecording();
    }
  }

  /// Start recording audio
  Future<void> startRecording() async {
    final currentState = state.requireValue;
    if (!currentState.canStartRecording) return;

    // Stop any ongoing TTS
    if (currentState.isSpeaking) {
      await _ttsService.stop();
    }

    try {
      final started = await _audioRecorder.startRecording();

      if (started) {
        state = AsyncValue.data(currentState.copyWith(
          isRecording: true,
          error: null,
          transcribedText: null,
        ));
      } else {
        state = AsyncValue.data(currentState.copyWith(
          error: _audioRecorder.lastError ?? 'Failed to start recording',
        ));
      }
    } catch (e) {
      state = AsyncValue.data(currentState.copyWith(
        error: e.toString(),
      ));
    }
  }

  /// Stop recording and transcribe
  Future<String?> stopRecording() async {
    final currentState = state.requireValue;
    if (!currentState.isRecording) return null;

    try {
      // Stop recording
      final audioPath = await _audioRecorder.stopRecording();

      if (audioPath == null) {
        state = AsyncValue.data(currentState.copyWith(
          isRecording: false,
          error: 'Recording failed',
        ));
        return null;
      }

      // Update state to transcribing
      state = AsyncValue.data(currentState.copyWith(
        isRecording: false,
        isTranscribing: true,
      ));

      // Transcribe with Whisper
      final transcription = await _whisperService.transcribe(audioPath);

      // Clean up the audio file
      await _audioRecorder.deleteRecording(audioPath);

      if (transcription != null && transcription.isNotEmpty) {
        state = AsyncValue.data(state.requireValue.copyWith(
          isTranscribing: false,
          transcribedText: transcription,
          error: null,
        ));
        return transcription;
      } else {
        state = AsyncValue.data(state.requireValue.copyWith(
          isTranscribing: false,
          error: 'Could not transcribe audio',
        ));
        return null;
      }
    } catch (e) {
      state = AsyncValue.data(currentState.copyWith(
        isRecording: false,
        isTranscribing: false,
        error: e.toString(),
      ));
      return null;
    }
  }

  /// Cancel ongoing recording
  Future<void> cancelRecording() async {
    await _audioRecorder.cancelRecording();
    state = AsyncValue.data(state.requireValue.copyWith(
      isRecording: false,
      isTranscribing: false,
    ));
  }

  /// Speak text using TTS
  Future<void> speak(String text) async {
    final currentState = state.requireValue;

    // Don't speak if voice mode is disabled or already speaking
    if (!currentState.isVoiceModeEnabled) return;

    try {
      state = AsyncValue.data(currentState.copyWith(isSpeaking: true));
      await _ttsService.speak(text);

      // Wait for completion
      while (_ttsService.isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      state = AsyncValue.data(state.requireValue.copyWith(isSpeaking: false));
    } catch (e) {
      state = AsyncValue.data(state.requireValue.copyWith(
        isSpeaking: false,
        error: e.toString(),
      ));
    }
  }

  /// Stop TTS
  Future<void> stopSpeaking() async {
    await _ttsService.stop();
    state = AsyncValue.data(state.requireValue.copyWith(isSpeaking: false));
  }

  /// Toggle voice mode (auto-speak)
  void toggleVoiceMode() {
    final currentState = state.requireValue;
    state = AsyncValue.data(currentState.copyWith(
      isVoiceModeEnabled: !currentState.isVoiceModeEnabled,
    ));
  }

  /// Enable voice mode
  void enableVoiceMode() {
    state = AsyncValue.data(state.requireValue.copyWith(
      isVoiceModeEnabled: true,
    ));
  }

  /// Disable voice mode
  void disableVoiceMode() {
    state = AsyncValue.data(state.requireValue.copyWith(
      isVoiceModeEnabled: false,
    ));
  }

  /// Clear any errors
  void clearError() {
    state = AsyncValue.data(state.requireValue.copyWith(error: null));
  }

  /// Clear transcribed text
  void clearTranscription() {
    state = AsyncValue.data(state.requireValue.copyWith(transcribedText: null));
  }

  /// Check if microphone permission is granted
  Future<bool> checkMicrophonePermission() async {
    return await _audioRecorder.hasPermission();
  }
}
