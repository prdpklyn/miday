# FunctionGemma Flutter Setup (iOS + Android)

This document describes the exact model artifacts in this repo, how to load them in Flutter, and the function-call contract the model was trained to generate.

## 1) Model Artifacts In This Repo

Current mobile-ready artifacts:

- Quantized TFLite model: `functiongemma-myday.tflite` (~262 MB)
- Merged base+LoRA model: `functiongemma-myday-merged/`
- LoRA adapter (training artifact): `functiongemma-myday-finetuned/`

Merged model files (`functiongemma-myday-merged/`):

- `model.safetensors` (~1.0 GB)
- `tokenizer.json` (~32 MB)
- `tokenizer_config.json`
- `config.json`
- `generation_config.json`

## 2) Runtime Tensor Contract (TFLite)

The exported TFLite model currently uses fixed-length inputs with `sample_length=256`.

- Input tensor name: `serving_default_args_0:0`
- Input shape: `[1, 256]`
- Input dtype: `int64`
- Output tensor name: `StatefulPartitionedCall:0`
- Output shape: `[1, 256, 262144]`
- Output dtype: `float32`

Implications:

- You must tokenize text into token IDs and pad/truncate to length `256`.
- Generation is done by reading logits from output and selecting next tokens (usually greedy for function-calling).

## 3) Prompt Format Required By This Model

Use this exact template:

```text
<|developer|>You are a model that can do function calling with the following functions</s>
<|user|>{USER_INPUT}</s>
<|assistant|>
```

Expected model output format:

```text
<start_function_call>call:FUNCTION_NAME{key:<escape>value<escape>,...}<end_function_call>
```

## 4) Supported Functions

Functions detected from training data in `miday_training_data.JSONL`:

- `add_event(title, date, start_time, end_time?, location?, attendees?)`
- `reschedule_event(event_ref, new_date?, new_time?)`
- `cancel_event(event_ref)`
- `add_task(title, due_date?, due_time?, priority?, category?, linked_event?)`
- `complete_task(task_ref)`
- `defer_task(task_ref, new_date)`
- `create_note(content, title?, tags?, linked_event?, linked_task?)`
- `append_note(note_ref, content?, tags?)`
- `search_notes(query?, tags?)`
- `search_all(query, date_range?)`
- `list_today(include_schedule?, include_tasks?, include_notes?)`

### Function Output Examples

```text
<start_function_call>call:add_event{title:<escape>Dentist<escape>,date:<escape>tomorrow<escape>,start_time:<escape>14:00<escape>}<end_function_call>
```

```text
<start_function_call>call:add_task{title:<escape>Send the report<escape>,due_date:<escape>today<escape>,due_time:<escape>15:00<escape>}<end_function_call>
```

```text
<start_function_call>call:search_all{query:<escape>John<escape>}<end_function_call>
```

## 5) Flutter Dependencies

In `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  tflite_flutter: ^0.10.4
```

Add model asset:

```yaml
flutter:
  assets:
    - assets/models/functiongemma-myday.tflite
```

Copy model file:

- From: `functiongemma-myday.tflite`
- To: `<your_flutter_app>/assets/models/functiongemma-myday.tflite`

## 6) Android Setup

In `<your_flutter_app>/android/app/build.gradle` set:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

Notes:

- Use release builds for performance (`flutter run --release`).
- Keep tokenizer + inference off the UI thread (isolate/background worker).

## 7) iOS Setup

In `<your_flutter_app>/ios/Podfile` ensure platform is at least:

```ruby
platform :ios, '12.0'
```

Then run:

```bash
cd ios
pod install
```

Notes:

- Run on real device for realistic latency/memory.
- Prefer release/profile builds for inference testing.

## 8) Minimal Flutter Inference Skeleton

```dart
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class FunctionGemmaTflite {
  static const int seqLen = 256;
  static const int vocabSize = 262144;

  late final Interpreter _interpreter;

  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/functiongemma-myday.tflite',
      options: InterpreterOptions()..threads = 4,
    );
  }

  Float32List run(Int64List inputIds) {
    // inputIds is a flat [1, 256] int64 tensor
    if (inputIds.length != seqLen) {
      throw ArgumentError('Expected $seqLen token IDs.');
    }

    // Flat output buffer for [1, 256, 262144]
    final output = Float32List(seqLen * vocabSize);
    _interpreter.run(inputIds, output);
    return output;
  }

  int argmaxAtPosition(Float32List logits, int position) {
    final base = position * vocabSize;
    var bestId = 0;
    var bestVal = logits[base];
    for (var i = 1; i < vocabSize; i++) {
      final v = logits[base + i];
      if (v > bestVal) {
        bestVal = v;
        bestId = i;
      }
    }
    return bestId;
  }

  void close() {
    _interpreter.close();
  }
}
```

## 9) Tokenization + Decoding Requirements

Critical requirement:

- Model quality depends on using the same tokenizer family as training (`tokenizer.json` from model artifacts).
- One inference output buffer is large (`256 * 262144 * 4` bytes ~= `268 MB` float32). Plan memory accordingly.

Practical integration options:

1. On-device tokenizer implementation compatible with `tokenizer.json`.
2. Hybrid approach: tokenize/detokenize in backend, run only inference on-device.
3. Full backend inference (simplest operationally, least on-device complexity).

If you need full on-device function calling, implement and validate tokenizer parity first.

If memory pressure is high on target devices, re-export with smaller `sample_length` (for example `128`) and validate quality:

```bash
python convert_to_tflite.py --sample-length 128 --model-path ./functiongemma-myday-merged --output ./functiongemma-myday.tflite
```

## 10) Function Call Parsing In App

Parse only text between:

- Start token: `<start_function_call>`
- End token: `<end_function_call>`

Then extract:

- Function name after `call:` and before `{`
- Key/value pairs inside `{...}`

Reject outputs that do not match this envelope.

## 11) Validation Checklist

1. Model loads on both Android and iOS release builds.
2. Prompt template is exact (including special tags).
3. Input tensor shape and dtype are correct (`[1,256]`, int64 values).
4. Output parser extracts function calls strictly from the envelope.
5. Smoke tests pass for each supported function family (event/task/note/search/list).

## 12) Reference Commands (This Repo)

Re-merge LoRA into base model:

```bash
python merge_model_for_mobile.py --device mps
```

Re-export TFLite:

```bash
# Uses quantized dynamic INT8 recipe by default
python convert_to_tflite.py --model-path ./functiongemma-myday-merged --output ./functiongemma-myday.tflite
```
