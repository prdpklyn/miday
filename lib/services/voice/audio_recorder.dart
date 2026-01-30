import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Service for recording audio from the microphone.
/// Records to a temporary WAV file for Whisper transcription.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;
  String? _lastError;

  bool get isRecording => _isRecording;
  String? get lastError => _lastError;

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    if (_isRecording) {
      print('Already recording');
      return false;
    }

    try {
      // Check permission
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _lastError = 'Microphone permission not granted';
        return false;
      }

      // Generate temp file path for recording
      _currentRecordingPath = await _generateTempFilePath();

      // Configure recording for Whisper compatibility
      // Whisper works best with 16kHz mono WAV
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _lastError = null;
      print('Recording started: $_currentRecordingPath');
      return true;
    } catch (e, stack) {
      _lastError = e.toString();
      print('Failed to start recording: $e');
      print(stack);
      return false;
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      print('Not currently recording');
      return null;
    }

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      print('Recording stopped: $path');

      // Verify the file exists and has content
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          print('Recording file size: $size bytes');
          if (size > 0) {
            return path;
          }
        }
      }

      _lastError = 'Recording file is empty or missing';
      return null;
    } catch (e, stack) {
      _lastError = e.toString();
      print('Failed to stop recording: $e');
      print(stack);
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording and delete the file
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }

    // Clean up the file
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
      _currentRecordingPath = null;
    }
  }

  /// Generate a unique temp file path for recording
  Future<String> _generateTempFilePath() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${tempDir.path}/voice_recording_$timestamp.wav';
  }

  /// Clean up old recording files
  Future<void> cleanupOldRecordings() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (final file in files) {
        if (file is File && file.path.contains('voice_recording_')) {
          // Delete files older than 1 hour
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);
          if (age.inHours >= 1) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Cleanup error: $e');
    }
  }

  /// Delete a specific recording file
  Future<void> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Delete error: $e');
    }
  }

  /// Get recording amplitude for visualization
  Future<double> getAmplitude() async {
    if (!_isRecording) return 0.0;

    try {
      final amplitude = await _recorder.getAmplitude();
      // Normalize the amplitude to 0-1 range
      // dB values typically range from -160 (silence) to 0 (max)
      final current = amplitude.current;
      if (current == double.negativeInfinity) return 0.0;
      return ((current + 60) / 60).clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }

  /// Dispose resources
  void dispose() {
    _recorder.dispose();
  }
}
