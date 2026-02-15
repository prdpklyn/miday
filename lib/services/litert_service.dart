import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class LiteRTService {
  static const MethodChannel _channel = MethodChannel('com.myday.my_day/litert');
  static const EventChannel _eventChannel = EventChannel('com.myday.my_day/litert/stream');
  Future<void> initialize() async {
    await _channel.invokeMethod('initialize');
  }
  Future<bool> detectVoiceActivity(Float32List audioData) async {
    final bool? result = await _channel.invokeMethod<bool>('detectVoiceActivity', {'audioData': audioData});
    return result ?? false;
  }
  Future<String> transcribe(Float32List audioData) async {
    final String? result = await _channel.invokeMethod<String>('transcribe', {'audioData': audioData});
    return result ?? '';
  }
  Future<FunctionCall> generateFunctionCall(String transcript) async {
    final Map<dynamic, dynamic>? result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'generateFunctionCall',
      {'transcript': transcript},
    );
    final Map<String, dynamic> json = _mapToStringKey(result ?? <dynamic, dynamic>{});
    return FunctionCall.fromJson(json);
  }
  Stream<PartialTranscript> transcribeStreaming(Stream<Float32List> audioChunks) {
    final StreamController<PartialTranscript> controller = StreamController<PartialTranscript>();
    final StreamSubscription<dynamic> eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final Map<String, dynamic> json = _mapToStringKey(event as Map<dynamic, dynamic>);
        controller.add(PartialTranscript.fromJson(json));
      },
      onError: controller.addError,
      onDone: controller.close,
    );
    final StreamSubscription<Float32List> audioSubscription = audioChunks.listen(
      (Float32List chunk) {
        _channel.invokeMethod('processAudioChunk', {'chunk': chunk});
      },
      onError: controller.addError,
      onDone: () async {
        await eventSubscription.cancel();
        await controller.close();
      },
    );
    controller.onCancel = () async {
      await audioSubscription.cancel();
      await eventSubscription.cancel();
    };
    return controller.stream;
  }
  void dispose() {
    _channel.invokeMethod('release');
  }
  Map<String, dynamic> _mapToStringKey(Map<dynamic, dynamic> source) {
    return source.map((dynamic key, dynamic value) => MapEntry<String, dynamic>(key.toString(), value));
  }
}

class FunctionCall {
  final String name;
  final Map<String, dynamic> parameters;
  FunctionCall({required this.name, required this.parameters});
  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    final Map<dynamic, dynamic> rawParams = json['parameters'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};
    final Map<String, dynamic> params = rawParams.map((dynamic key, dynamic value) {
      return MapEntry<String, dynamic>(key.toString(), value);
    });
    return FunctionCall(
      name: json['name'] as String? ?? '',
      parameters: params,
    );
  }
}

class PartialTranscript {
  final String text;
  final String? intent;
  final double confidence;
  PartialTranscript({required this.text, required this.confidence, this.intent});
  factory PartialTranscript.fromJson(Map<String, dynamic> json) {
    return PartialTranscript(
      text: json['text'] as String? ?? '',
      intent: json['intent'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
