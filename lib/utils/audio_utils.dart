import 'dart:typed_data';

Float32List bytesToFloats(Uint8List bytes) {
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

List<double> calculateAudioLevels(Float32List samples, {int buckets = 24}) {
  final int safeBuckets = buckets <= 0 ? 1 : buckets;
  final int bucketSize = samples.isEmpty ? 1 : (samples.length ~/ safeBuckets).clamp(1, samples.length);
  final List<double> levels = <double>[];
  for (int i = 0; i < safeBuckets; i++) {
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
    levels.add(rms.clamp(0, 1));
  }
  return levels;
}

class AudioRingBuffer {
  AudioRingBuffer({required this.capacity}) : _buffer = <double>[];
  final int capacity;
  final List<double> _buffer;
  int get length => _buffer.length;
  void addAll(Float32List samples) {
    _buffer.addAll(samples);
    if (_buffer.length > capacity) {
      final int overflow = _buffer.length - capacity;
      _buffer.removeRange(0, overflow);
    }
  }
  Float32List readAll() {
    return Float32List.fromList(_buffer);
  }
  void clear() {
    _buffer.clear();
  }
}
