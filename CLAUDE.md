# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**My Day (Mi-day)** is a voice-first Flutter productivity app with on-device AI inference. Users speak commands like "Schedule dentist tomorrow at 2pm" and the app executes them in ~400ms using LiteRT + FunctionGemma.

### Core Concept
- Voice input → Whisper (speech-to-text) → FunctionGemma (function calling) → Database action
- All AI runs on-device (no cloud dependency)
- Speculative execution predicts intent before user finishes speaking

## Build & Run Commands

```bash
# Install dependencies
flutter pub get

# Generate Drift database code (required after schema changes)
dart run build_runner build --delete-conflicting-outputs

# Run on device (debug)
flutter run

# Run release build (better AI inference performance)
flutter run --release

# iOS setup
cd ios && pod install && cd ..

# Run tests
flutter test

# Run single test file
flutter test test/path/to/test_file.dart
```

### Model Setup
Place the Gemma model file at `assets/models/gemma3-1b-it-int4.task` (not in git due to size).

## Architecture

### Layer Structure
```
Presentation (Riverpod providers, widgets)
     ↓
Services (voice_pipeline, function_router, litert, proactive, smart_linking)
     ↓
Data (Drift database, models)
     ↓
Native Bridges (Kotlin LiteRTBridge, Swift LiteRTBridge)
```

### Key Services

**VoicePipelineService** (`lib/services/voice_pipeline_service.dart`)
- Captures audio, runs VAD (voice activity detection), streams to Whisper
- Implements speculative execution when intent confidence > 0.9

**LiteRTService** (`lib/services/litert_service.dart`)
- Platform channel bridge to native LiteRT inference
- Loads VAD, Whisper, and FunctionGemma models

**FunctionRouterService** (`lib/services/function_router_service.dart`)
- Routes parsed function calls to database operations
- Handles reference resolution ("the meeting" → finds matching event)
- Parses relative dates ("tomorrow", "next Friday")

**SmartLinkingService** (`lib/services/smart_linking_service.dart`)
- Auto-connects related events, tasks, and notes

### Database (Drift)
- Schema: `lib/data/sources/app_database.dart`
- Generated code: `lib/data/sources/app_database.g.dart`
- Three main tables: Events, Tasks, Notes with foreign key relationships

### Native Bridges
- Android: `android/app/src/main/kotlin/com/myday/my_day/LiteRTBridge.kt`
- iOS: `ios/Runner/LiteRTBridge.swift`

## Function Calling Contract

FunctionGemma expects this prompt format:
```
<|developer|>You are a model that can do function calling with the following functions</s>
<|user|>{USER_INPUT}</s>
<|assistant|>
```

Output format:
```
<start_function_call>call:FUNCTION_NAME{key:<escape>value<escape>,...}<end_function_call>
```

Supported functions:
- `add_event`, `reschedule_event`, `cancel_event`
- `add_task`, `complete_task`, `defer_task`
- `create_note`, `append_note`, `search_notes`
- `list_today`, `search_all`

## Performance Targets

| Metric | Target |
|--------|--------|
| Voice → Action | < 400ms |
| Time-to-first-token | < 300ms |
| Memory footprint | < 600MB |
| Model size (total) | < 400MB |

## Voice Pipeline Status

The voice pipeline is implemented with the following components:

**Working:**
- Microphone permissions (iOS Info.plist + Android manifest)
- Audio capture and streaming via `record` package
- Energy-based VAD (voice activity detection)
- Transcription via Apple Speech Framework (iOS)
- Full error handling and recovery states
- VoiceWidget UI states: idle, requestingPermission, listening, processing, executing, complete, error

**Models in assets/models/:**
- `silero_vad.tflite` (~298KB) - VAD model (loaded but using energy fallback)
- `ggml-tiny.en.bin` (~75MB) - Whisper GGML (for future whisper.cpp integration)
- `functiongemma-myday.tflite` (~262MB) - Fine-tuned function calling
- `gemma3-1b-it-int4.task` (~555MB) - General Gemma model

**TODO:**
- Proper tokenization for FunctionGemma
- Greedy decoding for FunctionGemma output
- Replace Apple Speech with whisper.cpp for offline accuracy

See `docs/plans/2026-02-06-voice-pipeline-ios-design.md` for full design.

## State Management

Uses Riverpod. Key providers in `lib/presentation/providers/`:
- `voice_pipeline_provider.dart` - Voice state (idle, listening, processing, executing)
- `timeline_provider.dart` - Combined view of events/tasks/notes
- `tab_provider.dart` - Active view tab
- `data_providers.dart` - Database access

## UI Components

- `VoiceWidget` - Main voice input with waveform visualization
- `GhostCard` - Speculative preview of pending action
- `TimelineView` - Combined chronological view
- `SwipeableTaskCard` - Gesture-based task completion/deferral

## Training Pipeline

Located in `training/`:
- `function_schema.py` - Function definitions
- `generate_training_data.py` - Creates training examples
- `finetune_functiongemma.py` - LoRA fine-tuning
- `convert_to_tflite.py` - INT8 quantization export

## iOS Deployment

Fastlane configured for TestFlight/App Store. See `docs/ios-deployment.md` and `ios/fastlane/`.

```bash
cd ios
bundle exec fastlane beta  # Deploy to TestFlight
```
