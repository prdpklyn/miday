# Voice Pipeline iOS Implementation

> Design document for integrating on-device voice processing with whisper.cpp + FunctionGemma on iOS.

## Overview

Transform the My Day app's voice input from non-functional stubs to a fully working on-device pipeline using:
- **Silero VAD** (TFLite) — Voice activity detection
- **whisper.cpp** (GGML) — Speech-to-text
- **FunctionGemma** (TFLite) — Function calling

Target: Seamless voice UX with <500ms perceived latency.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      FLUTTER LAYER                          │
│  VoiceWidget → VoicePipelineService → LiteRTService        │
└─────────────────────────────────────────────────────────────┘
                            ↓ Platform Channel
┌─────────────────────────────────────────────────────────────┐
│                   iOS NATIVE LAYER (Swift)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Silero VAD   │  │ whisper.cpp  │  │ FunctionGemma│      │
│  │ (TFLite)     │  │ (GGML)       │  │ (TFLite)     │      │
│  │ ~2MB         │  │ ~75MB        │  │ ~262MB       │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Models Required

| Model | File | Format | Size | Source |
|-------|------|--------|------|--------|
| Silero VAD | `silero_vad.tflite` | TFLite | ~2MB | [Silero GitHub](https://github.com/snakers4/silero-vad) |
| Whisper | `ggml-tiny.en.bin` | GGML | ~75MB | Already in assets |
| FunctionGemma | `functiongemma-myday.tflite` | TFLite | ~262MB | Already in assets |

## Implementation Phases

### Phase 1: Permissions & Error Handling
- [x] Add NSMicrophoneUsageDescription to Info.plist
- [x] Add NSSpeechRecognitionUsageDescription to Info.plist
- [x] Add RECORD_AUDIO to Android manifest
- [x] Add runtime permission request in VoicePipelineService
- [x] Add try-catch error handling in VoicePipelineService
- [x] Show errors in VoiceWidget UI
- [x] Add requestingPermission state

### Phase 2: Setup Models
- [x] Download Silero VAD TFLite model (~298KB)
- [x] Add to assets folder
- [x] Update pubspec.yaml assets list (all 4 models)

### Phase 3: iOS Native Bridge
- [x] TensorFlowLiteSwift available via flutter_gemma
- [x] Implement energy-based VAD (Silero model loaded but using energy fallback)
- [x] Implement transcription using Apple Speech Framework (temporary)
- [x] Implement FunctionGemma TFLite inference structure
- [x] Wire up all platform channel methods
- [ ] TODO: Implement proper tokenization for FunctionGemma
- [ ] TODO: Implement greedy decoding for FunctionGemma output
- [ ] TODO: Replace Apple Speech with whisper.cpp for better offline support

### Phase 4: Polish & Test
- [ ] Model loading states
- [ ] Waveform animation smoothing
- [ ] Haptic feedback
- [ ] End-to-end testing

## Voice Flow

1. **Idle** → User taps mic button
2. **Requesting Permission** → Check/request microphone access
3. **Listening** → Stream audio, run VAD every 30ms
4. **Speech Detected** → Buffer audio, show waveform
5. **Silence Detected** → Stop recording after 1.5s silence
6. **Processing** → Run Whisper transcription
7. **Executing** → Run FunctionGemma, execute result
8. **Complete** → Show confirmation, reset after 2s

## Error Handling

| Error | User Message | Recovery |
|-------|--------------|----------|
| Permission denied | "Microphone access needed" | Show settings button |
| Model load failed | "Voice features loading..." | Retry on next tap |
| Transcription empty | "Didn't catch that" | Auto-reset to idle |
| Function parse failed | "Couldn't understand" | Show transcript, suggest retry |

## Platform Channel API

```dart
// Methods
Future<void> initialize()
Future<bool> detectVoiceActivity(Float32List audioData)
Future<String> transcribe(Float32List audioData)
Future<Map> generateFunctionCall(String transcript)
void processAudioChunk(Float32List chunk)
void release()

// Events (streaming)
Stream<PartialTranscript> → {text, intent, confidence}
```

## Dependencies

### iOS (Podfile)
```ruby
pod 'TensorFlowLiteSwift', '~> 2.14'
```

### Swift Package
```
whisper.cpp - https://github.com/ggerganov/whisper.cpp
```

## Success Criteria

- [ ] Tap mic → waveform appears within 100ms
- [ ] Speech transcribed within 500ms of silence
- [ ] Function executed within 300ms of transcription
- [ ] Error states always visible and recoverable
- [ ] Works fully offline
