---
name: My Day V2 Implementation
overview: Complete implementation plan for transforming My Day into a voice-first productivity app with on-device AI using LiteRT + FunctionGemma, targeting sub-400ms voice-to-action latency through speculative execution, streaming inference, and hardware acceleration.
todos:
  - id: phase1-database
    content: "Phase 1.1: Migrate database from sqflite to Drift with foreign keys, timeline queries, and FTS"
    status: completed
  - id: phase1-android-bridge
    content: "Phase 1.2a: Create Android LiteRT native bridge (LiteRTBridge.kt, LiteRTPlugin.kt, MainActivity.kt)"
    status: completed
  - id: phase1-ios-bridge
    content: "Phase 1.2b: Create iOS LiteRT native bridge (LiteRTBridge.swift, AppDelegate.swift)"
    status: completed
  - id: phase1-deps
    content: "Phase 1.3: Update dependencies (pubspec.yaml, build.gradle.kts, Podfile)"
    status: completed
  - id: phase2-litert-service
    content: "Phase 2.1: Implement LiteRT Service with MethodChannel and EventChannel"
    status: completed
  - id: phase2-voice-pipeline
    content: "Phase 2.2: Implement Voice Pipeline Service with VAD, streaming transcription, speculative execution"
    status: completed
  - id: phase2-audio-utils
    content: "Phase 2.3: Create audio processing utilities (PCM conversion, RMS, ring buffer)"
    status: completed
  - id: phase3-training-data
    content: "Phase 3.1: Create training data generator with 500+ examples and augmentation"
    status: completed
  - id: phase3-finetune
    content: "Phase 3.2: Fine-tune FunctionGemma with LoRA and convert to TFLite INT8"
    status: completed
  - id: phase4-function-router
    content: "Phase 4.1: Implement Function Router Service with reference resolution"
    status: completed
  - id: phase4-smart-linking
    content: "Phase 4.2: Implement Smart Linking Engine for auto-connecting related items"
    status: completed
  - id: phase5-voice-widget
    content: "Phase 5.1: Build Voice Widget with waveform visualization and state management"
    status: completed
  - id: phase5-ghost-card
    content: "Phase 5.2: Build Ghost Card for speculative preview with animations"
    status: completed
  - id: phase5-timeline
    content: "Phase 5.3: Build Timeline View combining events, tasks, and notes"
    status: completed
  - id: phase6-proactive
    content: "Phase 6: Implement Proactive Engine for context-aware suggestions"
    status: completed
isProject: false
---

# My Day V2 - Voice-First AI Implementation Plan

## Executive Summary

Transform the existing My Day app from a text-based AI assistant into a **voice-first productivity system** with on-device inference using LiteRT + FunctionGemma. The architecture employs **speculative execution**, **streaming transcription**, and **probabilistic intent detection** to achieve the target ~400ms voice-to-action latency.

---

## Current State Analysis


| Component      | Current                    | Target                      | Gap                 |
| -------------- | -------------------------- | --------------------------- | ------------------- |
| Database       | sqflite (manual SQL)       | Drift (type-safe)           | Migration required  |
| AI Engine      | flutter_gemma (Gemma 3 1B) | LiteRT + FunctionGemma 270M | Complete rewrite    |
| Voice Input    | None                       | Whisper Tiny + VAD          | New implementation  |
| Native Bridges | None                       | Kotlin/Swift LiteRT         | New implementation  |
| UI             | Text-based chat            | Voice-first with waveforms  | Significant changes |


**Reusable Assets:**

- Data models (`[lib/data/models/](lib/data/models/)`) - need minor schema updates
- Provider architecture (`[lib/presentation/providers/](lib/presentation/providers/)`)
- Basic UI structure and screens
- Existing function handler patterns (`[lib/services/ai/function_handler.dart](lib/services/ai/function_handler.dart)`)

---

## Architecture: Mathematical Models for Latency Optimization

### 1. Speculative Execution Pipeline

The key to achieving <400ms latency is **parallel speculation** - predicting the user's intent before they finish speaking:

```
Audio Stream → [VAD] → [Streaming Whisper] → [Intent Predictor] → [Speculative Prep]
                              ↓                        ↓
                       Partial Transcript         P(intent|words)
                              ↓                        ↓
                    [FunctionGemma] ←── (when confidence > θ, pre-warm)
```

**Confidence Threshold Model:**

```
θ_execute = argmax { θ : E[latency_saved(θ)] > E[cost_of_rollback(θ)] }
```

Where:

- `latency_saved(θ)` = time saved by speculative execution
- `cost_of_rollback(θ)` = wasted computation if prediction wrong

Empirically: **θ = 0.85** provides optimal tradeoff.

### 2. Intent Prediction via Bayesian Inference

Use n-gram language model on partial transcripts:

```
P(intent | words₁..ₙ) = P(words₁..ₙ | intent) × P(intent) / P(words₁..ₙ)
```

**Prior probabilities** from user history:

- `P(add_task)` ≈ 0.35 (most common)
- `P(add_event)` ≈ 0.25
- `P(create_note)` ≈ 0.15
- `P(query)` ≈ 0.15
- `P(modify)` ≈ 0.10

**Trigger words** for early detection:

- "Schedule", "Meeting", "Appointment" → `add_event` (boost +0.6)
- "Remind", "Task", "Todo" → `add_task` (boost +0.6)
- "Note", "Remember" → `create_note` (boost +0.5)
- "What", "Show", "List" → `query` (boost +0.5)

### 3. Voice Activity Detection (VAD) Energy Model

Custom energy-based VAD with Silero refinement:

```
E(frame) = Σ |x[n]|² / N

voice_detected = (E(frame) > μ_silence + 3σ_silence) ∧ silero_prob > 0.5
```

Calibrate `μ_silence` and `σ_silence` during first 500ms of recording.

### 4. Adaptive Silence Detection

Dynamic silence threshold based on speech rate:

```
silence_threshold = base_threshold × (1 + 0.1 × words_per_second)
```

Faster speakers get shorter silence windows (1.2s), slower speakers get longer (1.8s).

---

## Implementation Phases

### Phase 1: Foundation (Database + Native Bridges)

**1.1 Migrate to Drift Database**

Update `[lib/data/sources/database_helper.dart](lib/data/sources/database_helper.dart)` to use Drift:

- Add foreign key relationships for smart linking
- Implement timeline query combining events/tasks/notes
- Add full-text search with trigram indexing

**1.2 Create Native LiteRT Bridges**

Create platform-specific bridges:

**Android** (`android/app/src/main/kotlin/com/myday/my_day/`):

- `LiteRTBridge.kt` - Model loading, inference, buffer management
- `LiteRTPlugin.kt` - Platform channel handler

**iOS** (`ios/Runner/`):

- `LiteRTBridge.swift` - Model loading with Metal GPU delegate
- Platform channel integration in `AppDelegate.swift`

**1.3 Update Dependencies**

Add to `pubspec.yaml`:

```yaml
drift: ^2.14.1
sqlite3_flutter_libs: ^0.5.18
record: ^5.0.4
```

Add to Android `build.gradle.kts`:

```kotlin
implementation("com.google.ai.edge.litert:litert:2.0.0")
implementation("com.google.ai.edge.litert:litert-gpu:2.0.0")
```

Add to iOS `Podfile`:

```ruby
pod 'LiteRTSwift', '~> 2.0'
pod 'LiteRTMetalDelegate', '~> 2.0'
```

---

### Phase 2: Voice Pipeline Implementation

**2.1 LiteRT Service (Dart)**

Create `lib/services/litert_service.dart`:

- MethodChannel for native communication
- EventChannel for streaming transcription
- Zero-copy audio buffer handling

**2.2 Voice Pipeline Service**

Create `lib/services/voice_pipeline_service.dart`:

- Audio capture with `record` package (16kHz mono)
- VAD integration for speech boundary detection
- Streaming transcription with partial results
- Speculative intent detection

**2.3 Audio Processing Utilities**

Implement in `lib/utils/audio_utils.dart`:

- PCM16 to Float32 conversion (zero-copy)
- RMS energy calculation for waveform visualization
- Audio buffer ring management

---

### Phase 3: AI Model Pipeline

**3.1 Fine-tune FunctionGemma**

Create `training/` directory with:

- `function_schema.py` - My Day function definitions
- `generate_training_data.py` - 500+ training examples
- `finetune_functiongemma.py` - LoRA fine-tuning script
- `convert_to_tflite.py` - INT8 quantization + export

**Training data augmentation:**

- Paraphrase variations (5x per example)
- Typo injection for speech-to-text errors
- Context injection (time of day, recent items)

**3.2 Model Optimization**

Target model sizes:

- Silero VAD: ~2MB (CPU)
- Whisper Tiny: ~75MB (NPU preferred)
- FunctionGemma: ~288MB INT8 (GPU)

Quantization strategy:

- Dynamic INT8 for weights
- FP16 for activations on GPU
- Per-channel quantization for accuracy

---

### Phase 4: Function Router + Smart Linking

**4.1 Function Router Service**

Create `lib/services/function_router_service.dart`:

- Route function calls to database operations
- Reference resolution (fuzzy matching)
- Date/time parsing with relative expressions

**4.2 Reference Resolution Algorithm**

Fuzzy entity matching using Levenshtein distance:

```dart
Entity? resolve(String ref, List<Entity> candidates) {
  return candidates
    .map((e) => (e, levenshtein(ref.lower, e.title.lower) / max(ref.length, e.title.length)))
    .where((pair) => pair.$2 < 0.4) // 60% similarity threshold
    .minByOrNull((pair) => pair.$2)
    ?.$1;
}
```

**4.3 Smart Linking Engine**

Auto-link related items using:

- Temporal proximity (events within 1 hour of task due time)
- Semantic similarity (shared keywords in titles)
- Explicit mentions ("for the dentist appointment")

---

### Phase 5: UI Components

**5.1 Voice Widget**

Create `lib/ui/widgets/voice_widget.dart`:

- Pulsing microphone indicator
- Real-time waveform visualization (24 bars)
- Streaming transcript display
- Intent confidence badge

**5.2 Waveform Visualizer**

Create `lib/ui/widgets/waveform_visualizer.dart`:

- Cubic bezier interpolation for smooth bars
- RMS normalization per bucket
- Gradient coloring based on voice activity

**5.3 Ghost Card (Speculative Preview)**

Create `lib/ui/widgets/ghost_card.dart`:

- Semi-transparent preview of pending action
- Confidence percentage indicator
- Smooth fade-in/out animations
- Auto-dismiss on confirmation

**5.4 Timeline View**

Create `lib/ui/widgets/timeline_view.dart`:

- Combined chronological view
- Expandable linked items
- Drag-to-reschedule gestures

---

### Phase 6: Proactive Intelligence

**6.1 Proactive Engine Service**

Create `lib/services/proactive_service.dart`:

**Context-aware suggestions using temporal patterns:**

```dart
List<Suggestion> generateSuggestions(DateTime now, List<Event> events, List<Task> tasks) {
  final suggestions = <Suggestion>[];
  
  // Upcoming event reminders (30 min before)
  for (final event in events.where((e) => e.startTime.difference(now).inMinutes.between(25, 35))) {
    suggestions.add(Suggestion.eventReminder(event));
  }
  
  // Overdue task nudges
  for (final task in tasks.where((t) => t.dueDate?.isBefore(now) ?? false)) {
    suggestions.add(Suggestion.overdueTask(task));
  }
  
  // Morning briefing (7-9 AM)
  if (now.hour >= 7 && now.hour <= 9 && !shownBriefingToday) {
    suggestions.add(Suggestion.morningBriefing(events, tasks));
  }
  
  return suggestions..sort((a, b) => b.priority.compareTo(a.priority));
}
```

**6.2 Habit Learning**

Track user patterns:

- Common task creation times
- Frequent event types by day of week
- Preferred task categories

---

## Performance Targets


| Metric              | Target                | Measurement Strategy                           |
| ------------------- | --------------------- | ---------------------------------------------- |
| Voice to Action     | <400ms                | End-to-end timing from VAD trigger to DB write |
| Time to First Token | <300ms                | From speech end to first streaming word        |
| Memory Footprint    | <600MB                | Peak memory during inference                   |
| Model Load Time     | <2s cold, <100ms warm | App startup profiling                          |
| VAD Latency         | <5ms                  | Per-frame processing time                      |


**Latency Budget Breakdown:**

- VAD detection: 2ms
- Whisper inference: 50-80ms
- FunctionGemma inference: 200-280ms
- DB write + UI update: 20-40ms
- **Total: 272-402ms**

---

## File Structure

```
lib/
├── main.dart
├── database/
│   ├── database.dart (Drift)
│   └── database.g.dart
├── models/
│   ├── event.dart (updated)
│   ├── task.dart (updated)
│   ├── note.dart
│   └── timeline_item.dart (new)
├── providers/
│   └── providers.dart (updated)
├── services/
│   ├── litert_service.dart (new)
│   ├── voice_pipeline_service.dart (new)
│   ├── function_router_service.dart (new)
│   └── proactive_service.dart (new)
├── ui/
│   ├── screens/
│   │   └── home_screen.dart (updated)
│   └── widgets/
│       ├── voice_widget.dart (new)
│       ├── waveform_visualizer.dart (new)
│       ├── ghost_card.dart (new)
│       └── timeline_view.dart (new)
└── utils/
    ├── audio_utils.dart (new)
    └── date_utils.dart (new)

android/app/src/main/kotlin/com/myday/my_day/
├── LiteRTBridge.kt (new)
├── LiteRTPlugin.kt (new)
└── MainActivity.kt (updated)

ios/Runner/
├── LiteRTBridge.swift (new)
└── AppDelegate.swift (updated)

training/ (new)
├── function_schema.py
├── generate_training_data.py
├── finetune_functiongemma.py
└── convert_to_tflite.py
```

---

## Risk Mitigation


| Risk                        | Impact | Mitigation                                   |
| --------------------------- | ------ | -------------------------------------------- |
| LiteRT API changes          | High   | Pin versions, create abstraction layer       |
| Model too large             | Medium | Aggressive quantization, distillation        |
| NPU unavailable             | Medium | GPU fallback, CPU fallback chain             |
| Whisper accuracy            | Medium | Fine-tune on productivity vocab              |
| Speculative false positives | Low    | Conservative threshold (0.85), easy rollback |


---

## Success Criteria

- Voice command recognized and executed in <400ms on flagship devices
- Voice command recognized and executed in <600ms on mid-range devices
- 95%+ intent classification accuracy on test set
- Smooth waveform visualization at 60fps
- Memory footprint stays under 600MB during inference
- Cold start model loading under 2 seconds

