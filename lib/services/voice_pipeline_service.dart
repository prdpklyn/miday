import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:my_day/services/litert_service.dart';
import 'package:state_notifier/state_notifier.dart';

enum VoiceState { idle, requestingPermission, listening, processing, executing, complete, error }

class VoicePipelineState {
  final VoiceState state;
  final String? transcript;
  final String? intent;
  final double? confidence;
  final FunctionCall? functionCall;
  final String? error;
  final List<double> audioLevels;

  VoicePipelineState({
    this.state = VoiceState.idle,
    this.transcript,
    this.intent,
    this.confidence,
    this.functionCall,
    this.error,
    this.audioLevels = const <double>[],
  });

  VoicePipelineState copyWith({
    VoiceState? state,
    String? transcript,
    String? intent,
    double? confidence,
    FunctionCall? functionCall,
    String? error,
    List<double>? audioLevels,
  }) {
    return VoicePipelineState(
      state: state ?? this.state,
      transcript: transcript ?? this.transcript,
      intent: intent ?? this.intent,
      confidence: confidence ?? this.confidence,
      functionCall: functionCall ?? this.functionCall,
      error: error ?? this.error,
      audioLevels: audioLevels ?? this.audioLevels,
    );
  }
}

/// Processes a transcript through AI and executes the resulting action.
/// Returns the executed function name on success, or null on failure.
typedef TranscriptProcessor = Future<String?> Function(String transcript);

class VoicePipelineService extends StateNotifier<VoicePipelineState> {
  VoicePipelineService({
    required LiteRTService liteRT,
    required TranscriptProcessor processTranscript,
    AudioRecorder? recorder,
  })  : _liteRT = liteRT,
        _processTranscript = processTranscript,
        _recorder = recorder ?? AudioRecorder(),
        super(VoicePipelineState());

  final LiteRTService _liteRT;
  final TranscriptProcessor _processTranscript;
  final AudioRecorder _recorder;

  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _silenceTimer;
  Timer? _resetTimer;

  // Audio buffer to accumulate chunks for final transcription
  final List<double> _audioBuffer = <double>[];
  bool _hasDetectedSpeech = false;

  static const int _sampleRate = 16000;
  static const Duration _silenceTimeout = Duration(milliseconds: 1500);
  static const Duration _resetDelay = Duration(seconds: 2);

  Future<void> startListening() async {
    if (state.state == VoiceState.listening) return;

    // Reset audio buffer
    _audioBuffer.clear();
    _hasDetectedSpeech = false;

    // Check and request permission
    state = state.copyWith(state: VoiceState.requestingPermission, error: null);

    try {
      final bool hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(
          state: VoiceState.error,
          error: 'Microphone permission denied. Please enable in Settings.',
        );
        return;
      }

      state = state.copyWith(
        state: VoiceState.listening,
        transcript: null,
        intent: null,
        confidence: null,
        functionCall: null,
        error: null,
        audioLevels: List.filled(24, 0.0),
      );

      final Stream<Uint8List> stream = await _recorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ));

      _audioSubscription = stream.listen(
        (Uint8List data) async {
          if (state.state != VoiceState.listening) return;

          try {
            final Float32List floats = _bytesToFloats(data);

            // Update waveform visualization
            state = state.copyWith(audioLevels: _calculateAudioLevels(floats));

            // Detect voice activity
            final bool hasVoice = await _liteRT.detectVoiceActivity(floats);

            if (hasVoice) {
              _hasDetectedSpeech = true;
              _audioBuffer.addAll(floats);
              _resetSilenceTimer();
            } else if (_hasDetectedSpeech) {
              // Only start silence timer after we've detected speech
              _audioBuffer.addAll(floats);
              _startSilenceTimer();
            }
          } on PlatformException catch (e) {
            state = state.copyWith(
              state: VoiceState.error,
              error: 'Voice processing error: ${e.message}',
            );
            await cancel();
          }
        },
        onError: (dynamic error) {
          state = state.copyWith(
            state: VoiceState.error,
            error: 'Audio stream error: $error',
          );
        },
      );
    } on PlatformException catch (e) {
      state = state.copyWith(
        state: VoiceState.error,
        error: 'Failed to start recording: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        state: VoiceState.error,
        error: 'Unexpected error: $e',
      );
    }
  }

  Future<void> _finishListening() async {
    // Stop recording
    await _recorder.stop();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    _silenceTimer?.cancel();

    // Check if we have audio to process
    if (_audioBuffer.isEmpty) {
      state = state.copyWith(
        state: VoiceState.error,
        error: "Didn't catch that. Please try again.",
      );
      _scheduleReset();
      return;
    }

    try {
      // Transcribe audio
      state = state.copyWith(state: VoiceState.processing);

      final Float32List audioData = Float32List.fromList(_audioBuffer);
      final String transcript = await _liteRT.transcribe(audioData);

      if (transcript.isEmpty) {
        state = state.copyWith(
          state: VoiceState.error,
          error: "Didn't catch that. Please try again.",
        );
        _scheduleReset();
        return;
      }

      state = state.copyWith(transcript: transcript);

      // Process transcript through AI service and execute
      state = state.copyWith(state: VoiceState.executing);
      final String? functionName = await _processTranscript(transcript);

      if (functionName == null) {
        state = state.copyWith(
          state: VoiceState.error,
          error: "Couldn't understand: \"$transcript\"",
        );
        _scheduleReset();
        return;
      }

      state = state.copyWith(
        state: VoiceState.complete,
        functionCall: FunctionCall(name: functionName, parameters: <String, dynamic>{}),
      );
      _scheduleReset();
    } on PlatformException catch (e) {
      state = state.copyWith(
        state: VoiceState.error,
        error: 'Processing error: ${e.message}',
      );
      _scheduleReset();
    } catch (e) {
      state = state.copyWith(
        state: VoiceState.error,
        error: 'Unexpected error: $e',
      );
      _scheduleReset();
    }
  }

  void _scheduleReset() {
    _resetTimer?.cancel();
    _resetTimer = Timer(_resetDelay, () {
      if (mounted) {
        state = VoicePipelineState();
      }
    });
  }

  Future<void> cancel() async {
    _silenceTimer?.cancel();
    _resetTimer?.cancel();
    await _recorder.stop();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    _audioBuffer.clear();
    _hasDetectedSpeech = false;
    state = VoicePipelineState();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _resetTimer?.cancel();
    _audioSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _startSilenceTimer() {
    _silenceTimer ??= Timer(_silenceTimeout, _finishListening);
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  Float32List _bytesToFloats(Uint8List bytes) {
    final int sampleCount = bytes.lengthInBytes ~/ 2;
    final Float32List floats = Float32List(sampleCount);
    int index = 0;
    for (int i = 0; i < bytes.lengthInBytes - 1; i += 2) {
      final int sample = bytes[i] | (bytes[i + 1] << 8);
      final int signed = sample > 32767 ? sample - 65536 : sample;
      floats[index] = signed / 32768.0;
      index++;
    }
    return floats;
  }

  List<double> _calculateAudioLevels(Float32List samples) {
    const int buckets = 24;
    if (samples.isEmpty) return List.filled(buckets, 0.0);

    final int bucketSize = (samples.length / buckets).ceil().clamp(1, samples.length);
    final List<double> levels = <double>[];

    for (int i = 0; i < buckets; i++) {
      final int start = i * bucketSize;
      final int end = (start + bucketSize).clamp(0, samples.length);

      if (start >= samples.length) {
        levels.add(0);
        continue;
      }

      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += samples[j] * samples[j];
      }

      final int count = end - start;
      final double rms = count == 0 ? 0 : (sum / count);
      // Scale up for visibility (RMS values are typically very small)
      levels.add((rms * 10).clamp(0, 1));
    }

    return levels;
  }
}
