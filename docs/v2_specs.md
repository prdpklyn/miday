# My Day - Technical Specification

> Voice-first task management app powered by LiteRT + FunctionGemma

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Tech Stack](#tech-stack)
4. [LiteRT Integration](#litert-integration)
5. [FunctionGemma Fine-tuning](#functiongemma-fine-tuning)
6. [Voice Pipeline](#voice-pipeline)
7. [Database Schema](#database-schema)
8. [Flutter Implementation](#flutter-implementation)
9. [UI Components](#ui-components)
10. [Build & Deployment](#build--deployment)

---

## Overview

### Vision
A voice-first personal productivity app that feels instant (~400ms response) using on-device AI with LiteRT NPU/GPU acceleration.

### Core Features
- **Schedule**: Events with time, duration, location
- **Tasks**: Action items with priority, due dates
- **Notes**: Quick capture with tags and linking
- **Voice**: Natural language input for all operations
- **Smart Linking**: Auto-connect related items

### Performance Targets
| Metric | Target |
|--------|--------|
| Voice → Action | < 400ms |
| Time-to-first-token | < 300ms |
| Memory footprint | < 600MB |
| Model size (total) | < 400MB |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              FLUTTER APP                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Voice     │  │  Timeline   │  │   Views     │  │  Settings   │        │
│  │   Widget    │  │   View      │  │ (S/T/N)     │  │             │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────────────┘        │
└─────────┼────────────────┼────────────────┼─────────────────────────────────┘
          │                │                │
          ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SERVICE LAYER (Dart)                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │ VoicePipeline   │  │ FunctionRouter  │  │ ProactiveEngine │             │
│  │ Service         │  │ Service         │  │ Service         │             │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘             │
└───────────┼────────────────────┼────────────────────┼───────────────────────┘
            │                    │                    │
            ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PLATFORM CHANNEL / FFI                              │
│                    (Dart ↔ Kotlin/Swift Bridge)                             │
└─────────────────────────────────────────────────────────────────────────────┘
            │                    │                    │
            ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LITERT LAYER (Native)                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │ Silero VAD      │  │ Whisper Tiny    │  │ FunctionGemma   │             │
│  │ (.tflite)       │  │ (.tflite)       │  │ 270M (.tflite)  │             │
│  │ CPU - 2ms       │  │ NPU - 50ms      │  │ GPU - 300ms     │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
│                                                                             │
│                    CompiledModel API + TensorBuffer                         │
│                    Zero-copy | Async | Auto-accelerator                     │
└─────────────────────────────────────────────────────────────────────────────┘
            │                    │                    │
            ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HARDWARE ACCELERATION                               │
│         ┌──────────┐       ┌──────────┐       ┌──────────┐                 │
│         │   CPU    │       │   GPU    │       │   NPU    │                 │
│         │ XNNPACK  │       │ ML Drift │       │ QNN/Neuro│                 │
│         └──────────┘       └──────────┘       └──────────┘                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

### Flutter App
```yaml
# pubspec.yaml
name: my_day
description: Voice-first productivity app

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  riverpod: ^2.4.9
  flutter_riverpod: ^2.4.9
  
  # Database
  drift: ^2.14.1
  sqlite3_flutter_libs: ^0.5.18
  
  # Audio
  record: ^5.0.4
  just_audio: ^0.9.36
  
  # UI
  flutter_animate: ^4.3.0
  
  # Platform
  path_provider: ^2.1.1
  permission_handler: ^11.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.7
  drift_dev: ^2.14.1
```

### Native Dependencies

#### Android (build.gradle)
```groovy
dependencies {
    // LiteRT
    implementation 'com.google.ai.edge.litert:litert:2.0.0'
    implementation 'com.google.ai.edge.litert:litert-gpu:2.0.0'
    implementation 'com.google.ai.edge.litert:litert-support:2.0.0'
    
    // Qualcomm NPU (optional, for Snapdragon devices)
    implementation 'com.google.ai.edge.litert:litert-qnn:2.0.0'
}
```

#### iOS (Podfile)
```ruby
pod 'LiteRTSwift', '~> 2.0'
pod 'LiteRTMetalDelegate', '~> 2.0'
```

### Models Required
| Model | Size | Source | Accelerator |
|-------|------|--------|-------------|
| silero_vad.tflite | ~2MB | [Silero](https://github.com/snakers4/silero-vad) | CPU |
| whisper-tiny.tflite | ~75MB | Convert from OpenAI | NPU |
| functiongemma-270m-finetuned.tflite | ~288MB | Fine-tune + convert | GPU |

---

## LiteRT Integration

### Android Native Bridge

```kotlin
// android/app/src/main/kotlin/com/example/myday/LiteRTBridge.kt

package com.example.myday

import android.content.Context
import com.google.ai.edge.litert.Accelerator
import com.google.ai.edge.litert.CompiledModel
import com.google.ai.edge.litert.Environment
import com.google.ai.edge.litert.TensorBuffer
import kotlinx.coroutines.*

class LiteRTBridge(private val context: Context) {
    
    private lateinit var env: Environment
    private lateinit var vadModel: CompiledModel
    private lateinit var whisperModel: CompiledModel
    private lateinit var functionGemmaModel: CompiledModel
    
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    suspend fun initialize() = withContext(Dispatchers.IO) {
        // Create environment with NPU support
        env = Environment.create(
            BuiltinNpuAcceleratorProvider(context)
        )
        
        // Load VAD model (CPU for low latency)
        vadModel = CompiledModel.create(
            context.assets,
            "models/silero_vad.tflite",
            CompiledModel.Options(Accelerator.CPU)
        )
        
        // Load Whisper (NPU preferred, GPU fallback)
        whisperModel = CompiledModel.create(
            context.assets,
            "models/whisper-tiny.tflite",
            CompiledModel.Options(Accelerator.NPU, Accelerator.GPU),
            env
        )
        
        // Load FunctionGemma (GPU preferred)
        functionGemmaModel = CompiledModel.create(
            context.assets,
            "models/functiongemma-270m-finetuned.tflite",
            CompiledModel.Options(Accelerator.GPU, Accelerator.CPU),
            env
        )
    }
    
    // Voice Activity Detection
    suspend fun detectVoiceActivity(audioChunk: FloatArray): Boolean {
        val inputBuffers = vadModel.createInputBuffers()
        val outputBuffers = vadModel.createOutputBuffers()
        
        inputBuffers[0].writeFloat(audioChunk)
        vadModel.run(inputBuffers, outputBuffers)
        
        val probability = outputBuffers[0].readFloat()[0]
        return probability > 0.5f
    }
    
    // Transcribe audio
    suspend fun transcribe(audioData: FloatArray): String {
        val inputBuffers = whisperModel.createInputBuffers()
        val outputBuffers = whisperModel.createOutputBuffers()
        
        inputBuffers[0].writeFloat(audioData)
        
        // Async execution on NPU
        whisperModel.runAsync(inputBuffers, outputBuffers).await()
        
        val tokens = outputBuffers[0].readInt()
        return decodeWhisperTokens(tokens)
    }
    
    // Generate function call
    suspend fun generateFunctionCall(transcript: String): FunctionCall {
        val inputBuffers = functionGemmaModel.createInputBuffers()
        val outputBuffers = functionGemmaModel.createOutputBuffers()
        
        val prompt = buildPrompt(transcript)
        val tokenizedInput = tokenize(prompt)
        
        inputBuffers[0].writeInt(tokenizedInput)
        
        // Async execution on GPU
        functionGemmaModel.runAsync(inputBuffers, outputBuffers).await()
        
        val outputTokens = outputBuffers[0].readInt()
        return parseFunctionCall(decode(outputTokens))
    }
    
    // Streaming transcription for speculative execution
    fun transcribeStreaming(
        audioChunks: Flow<FloatArray>
    ): Flow<PartialTranscript> = flow {
        val buffer = mutableListOf<FloatArray>()
        
        audioChunks.collect { chunk ->
            buffer.add(chunk)
            
            // Transcribe every 200ms worth of audio
            if (buffer.size >= 4) {
                val combined = buffer.flatten().toFloatArray()
                val partial = transcribe(combined)
                
                // Speculative intent detection
                val intent = detectIntent(partial)
                
                emit(PartialTranscript(
                    text = partial,
                    intent = intent,
                    confidence = calculateConfidence(partial, intent)
                ))
            }
        }
    }
    
    private fun buildPrompt(transcript: String): String {
        return """
<|developer|>You are a model that can do function calling with the following functions</s>
<|user|>$transcript</s>
<|assistant|>
        """.trimIndent()
    }
    
    fun release() {
        scope.cancel()
        vadModel.close()
        whisperModel.close()
        functionGemmaModel.close()
    }
}

data class PartialTranscript(
    val text: String,
    val intent: String?,
    val confidence: Float
)

data class FunctionCall(
    val name: String,
    val parameters: Map<String, Any?>
)
```

### iOS Native Bridge

```swift
// ios/Runner/LiteRTBridge.swift

import Foundation
import LiteRTSwift

@objc class LiteRTBridge: NSObject {
    
    private var vadModel: CompiledModel?
    private var whisperModel: CompiledModel?
    private var functionGemmaModel: CompiledModel?
    
    @objc func initialize() async throws {
        // Create environment
        let env = try Environment()
        
        // Load VAD (CPU)
        vadModel = try CompiledModel(
            modelPath: Bundle.main.path(forResource: "silero_vad", ofType: "tflite")!,
            options: CompiledModel.Options(accelerators: [.cpu])
        )
        
        // Load Whisper (Metal GPU)
        whisperModel = try CompiledModel(
            modelPath: Bundle.main.path(forResource: "whisper-tiny", ofType: "tflite")!,
            options: CompiledModel.Options(accelerators: [.gpu, .cpu]),
            environment: env
        )
        
        // Load FunctionGemma (Metal GPU)
        functionGemmaModel = try CompiledModel(
            modelPath: Bundle.main.path(forResource: "functiongemma-270m-finetuned", ofType: "tflite")!,
            options: CompiledModel.Options(accelerators: [.gpu, .cpu]),
            environment: env
        )
    }
    
    @objc func transcribe(audioData: [Float]) async throws -> String {
        guard let model = whisperModel else {
            throw LiteRTError.modelNotLoaded
        }
        
        let inputBuffers = try model.createInputBuffers()
        let outputBuffers = try model.createOutputBuffers()
        
        try inputBuffers[0].write(audioData)
        try await model.runAsync(inputBuffers, outputBuffers)
        
        let tokens: [Int32] = try outputBuffers[0].read()
        return decodeWhisperTokens(tokens)
    }
    
    @objc func generateFunctionCall(transcript: String) async throws -> [String: Any] {
        guard let model = functionGemmaModel else {
            throw LiteRTError.modelNotLoaded
        }
        
        let inputBuffers = try model.createInputBuffers()
        let outputBuffers = try model.createOutputBuffers()
        
        let prompt = buildPrompt(transcript)
        let tokens = tokenize(prompt)
        
        try inputBuffers[0].write(tokens)
        try await model.runAsync(inputBuffers, outputBuffers)
        
        let outputTokens: [Int32] = try outputBuffers[0].read()
        return parseFunctionCall(decode(outputTokens))
    }
}
```

### Flutter Platform Channel

```dart
// lib/services/litert_service.dart

import 'dart:async';
import 'package:flutter/services.dart';

class LiteRTService {
  static const _channel = MethodChannel('com.example.myday/litert');
  static const _eventChannel = EventChannel('com.example.myday/litert/stream');
  
  Future<void> initialize() async {
    await _channel.invokeMethod('initialize');
  }
  
  Future<String> transcribe(Float32List audioData) async {
    final result = await _channel.invokeMethod('transcribe', {
      'audioData': audioData,
    });
    return result as String;
  }
  
  Future<FunctionCall> generateFunctionCall(String transcript) async {
    final result = await _channel.invokeMethod('generateFunctionCall', {
      'transcript': transcript,
    });
    return FunctionCall.fromJson(result as Map<String, dynamic>);
  }
  
  Stream<PartialTranscript> transcribeStreaming(Stream<Float32List> audioChunks) {
    final controller = StreamController<PartialTranscript>();
    
    // Set up event channel listener
    _eventChannel.receiveBroadcastStream().listen((event) {
      controller.add(PartialTranscript.fromJson(event));
    });
    
    // Send audio chunks to native
    audioChunks.listen((chunk) {
      _channel.invokeMethod('processAudioChunk', {'chunk': chunk});
    });
    
    return controller.stream;
  }
  
  void dispose() {
    _channel.invokeMethod('release');
  }
}

class FunctionCall {
  final String name;
  final Map<String, dynamic> parameters;
  
  FunctionCall({required this.name, required this.parameters});
  
  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    return FunctionCall(
      name: json['name'] as String,
      parameters: json['parameters'] as Map<String, dynamic>,
    );
  }
}

class PartialTranscript {
  final String text;
  final String? intent;
  final double confidence;
  
  PartialTranscript({
    required this.text,
    this.intent,
    required this.confidence,
  });
  
  factory PartialTranscript.fromJson(Map<String, dynamic> json) {
    return PartialTranscript(
      text: json['text'] as String,
      intent: json['intent'] as String?,
      confidence: json['confidence'] as double,
    );
  }
}
```

---

## FunctionGemma Fine-tuning

### Function Schema

```python
# training/function_schema.py

MYDAY_FUNCTIONS = [
    # SCHEDULE
    {
        "type": "function",
        "function": {
            "name": "add_event",
            "description": "Add a calendar event or appointment",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "Event title"},
                    "date": {"type": "string", "description": "Date (YYYY-MM-DD or relative like 'tomorrow')"},
                    "start_time": {"type": "string", "description": "Start time (HH:MM)"},
                    "end_time": {"type": "string", "description": "End time (HH:MM)"},
                    "location": {"type": "string", "description": "Location"},
                    "attendees": {"type": "array", "items": {"type": "string"}}
                },
                "required": ["title", "date", "start_time"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "reschedule_event",
            "description": "Move an event to a different time",
            "parameters": {
                "type": "object",
                "properties": {
                    "event_ref": {"type": "string", "description": "Reference to event (title or 'the meeting')"},
                    "new_date": {"type": "string"},
                    "new_time": {"type": "string"}
                },
                "required": ["event_ref"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "cancel_event",
            "description": "Cancel/delete an event",
            "parameters": {
                "type": "object",
                "properties": {
                    "event_ref": {"type": "string"}
                },
                "required": ["event_ref"]
            }
        }
    },
    
    # TASKS
    {
        "type": "function",
        "function": {
            "name": "add_task",
            "description": "Add a task or reminder",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "Task description"},
                    "due_date": {"type": "string", "description": "Due date"},
                    "due_time": {"type": "string", "description": "Due time for reminder"},
                    "priority": {"type": "string", "enum": ["low", "medium", "high"]},
                    "category": {"type": "string"},
                    "linked_event": {"type": "string", "description": "Reference to related event"}
                },
                "required": ["title"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "complete_task",
            "description": "Mark a task as done",
            "parameters": {
                "type": "object",
                "properties": {
                    "task_ref": {"type": "string"}
                },
                "required": ["task_ref"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "defer_task",
            "description": "Postpone a task",
            "parameters": {
                "type": "object",
                "properties": {
                    "task_ref": {"type": "string"},
                    "new_date": {"type": "string"}
                },
                "required": ["task_ref", "new_date"]
            }
        }
    },
    
    # NOTES
    {
        "type": "function",
        "function": {
            "name": "create_note",
            "description": "Create a quick note",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "content": {"type": "string", "description": "Note content"},
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "linked_event": {"type": "string"},
                    "linked_task": {"type": "string"}
                },
                "required": ["content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "append_note",
            "description": "Add content to existing note",
            "parameters": {
                "type": "object",
                "properties": {
                    "note_ref": {"type": "string"},
                    "content": {"type": "string"}
                },
                "required": ["note_ref", "content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "search_notes",
            "description": "Search notes by content or tags",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "tags": {"type": "array", "items": {"type": "string"}}
                }
            }
        }
    },
    
    # CROSS-CUTTING
    {
        "type": "function",
        "function": {
            "name": "list_today",
            "description": "Show today's schedule, tasks, and notes",
            "parameters": {
                "type": "object",
                "properties": {
                    "include_schedule": {"type": "boolean", "default": True},
                    "include_tasks": {"type": "boolean", "default": True},
                    "include_notes": {"type": "boolean", "default": False}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "search_all",
            "description": "Search across schedule, tasks, and notes",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "date_range": {"type": "string"}
                },
                "required": ["query"]
            }
        }
    }
]
```

### Training Data Format

```python
# training/generate_training_data.py

TRAINING_EXAMPLES = [
    # SCHEDULE examples
    {
        "input": "Schedule dentist tomorrow at 2pm",
        "output": '<start_function_call>call:add_event{title:<escape>Dentist<escape>,date:<escape>tomorrow<escape>,start_time:<escape>14:00<escape>}<end_function_call>'
    },
    {
        "input": "Meeting with John on Friday 3 to 4pm at the office",
        "output": '<start_function_call>call:add_event{title:<escape>Meeting with John<escape>,date:<escape>Friday<escape>,start_time:<escape>15:00<escape>,end_time:<escape>16:00<escape>,location:<escape>the office<escape>}<end_function_call>'
    },
    {
        "input": "Move the dentist to Thursday",
        "output": '<start_function_call>call:reschedule_event{event_ref:<escape>dentist<escape>,new_date:<escape>Thursday<escape>}<end_function_call>'
    },
    {
        "input": "Cancel my meeting with John",
        "output": '<start_function_call>call:cancel_event{event_ref:<escape>meeting with John<escape>}<end_function_call>'
    },
    
    # TASK examples
    {
        "input": "Remind me to call mom",
        "output": '<start_function_call>call:add_task{title:<escape>Call mom<escape>}<end_function_call>'
    },
    {
        "input": "Add high priority task to review the contract by Friday",
        "output": '<start_function_call>call:add_task{title:<escape>Review the contract<escape>,due_date:<escape>Friday<escape>,priority:<escape>high<escape>}<end_function_call>'
    },
    {
        "input": "I finished the report",
        "output": '<start_function_call>call:complete_task{task_ref:<escape>report<escape>}<end_function_call>'
    },
    {
        "input": "Push the contract review to next week",
        "output": '<start_function_call>call:defer_task{task_ref:<escape>contract review<escape>,new_date:<escape>next week<escape>}<end_function_call>'
    },
    {
        "input": "Remind me to bring insurance card for the dentist appointment",
        "output": '<start_function_call>call:add_task{title:<escape>Bring insurance card<escape>,linked_event:<escape>dentist appointment<escape>}<end_function_call>'
    },
    
    # NOTE examples
    {
        "input": "Note ask about ultrasound schedule",
        "output": '<start_function_call>call:create_note{content:<escape>Ask about ultrasound schedule<escape>}<end_function_call>'
    },
    {
        "input": "Note for the John meeting discuss Q2 budget",
        "output": '<start_function_call>call:create_note{content:<escape>Discuss Q2 budget<escape>,linked_event:<escape>John meeting<escape>}<end_function_call>'
    },
    {
        "input": "Tag that note with work and urgent",
        "output": '<start_function_call>call:append_note{note_ref:<escape>last<escape>,tags:<escape>["work","urgent"]<escape>}<end_function_call>'
    },
    {
        "input": "Find my notes about budget",
        "output": '<start_function_call>call:search_notes{query:<escape>budget<escape>}<end_function_call>'
    },
    
    # QUERY examples
    {
        "input": "What's on my plate today",
        "output": '<start_function_call>call:list_today{}<end_function_call>'
    },
    {
        "input": "Show me tomorrow's schedule",
        "output": '<start_function_call>call:list_today{include_tasks:<escape>false<escape>,include_notes:<escape>false<escape>}<end_function_call>'
    },
    {
        "input": "What do I have with John",
        "output": '<start_function_call>call:search_all{query:<escape>John<escape>}<end_function_call>'
    },
    
    # Ambiguous / Edge cases
    {
        "input": "Lunch with Sarah",
        "output": '<start_function_call>call:add_event{title:<escape>Lunch with Sarah<escape>,date:<escape>today<escape>,start_time:<escape>12:00<escape>}<end_function_call>'
    },
    {
        "input": "Get groceries",
        "output": '<start_function_call>call:add_task{title:<escape>Get groceries<escape>}<end_function_call>'
    },
    {
        "input": "Remember the milk",
        "output": '<start_function_call>call:add_task{title:<escape>Buy milk<escape>}<end_function_call>'
    },
]
```

### Fine-tuning Script

```python
# training/finetune_functiongemma.py

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from peft import LoraConfig, get_peft_model
from datasets import Dataset
from trl import SFTTrainer

# Load base model
model_id = "google/functiongemma-270m-it"
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=torch.bfloat16,
    device_map="auto"
)

# LoRA config for efficient fine-tuning
lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    lora_dropout=0.05,
    target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
    task_type="CAUSAL_LM"
)

model = get_peft_model(model, lora_config)

# Prepare dataset
def format_example(example):
    return {
        "text": f"""<|developer|>You are a model that can do function calling with the following functions</s>
<|user|>{example['input']}</s>
<|assistant|>{example['output']}</s>"""
    }

dataset = Dataset.from_list(TRAINING_EXAMPLES)
dataset = dataset.map(format_example)

# Training arguments
training_args = TrainingArguments(
    output_dir="./functiongemma-myday",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    warmup_steps=100,
    logging_steps=10,
    save_steps=100,
    bf16=True,
)

# Train
trainer = SFTTrainer(
    model=model,
    train_dataset=dataset,
    args=training_args,
    tokenizer=tokenizer,
    dataset_text_field="text",
    max_seq_length=512,
)

trainer.train()

# Save
model.save_pretrained("./functiongemma-myday-finetuned")
tokenizer.save_pretrained("./functiongemma-myday-finetuned")
```

### Convert to TFLite

```python
# training/convert_to_tflite.py

import torch
from transformers import AutoModelForCausalLM
import ai_edge_torch

# Load fine-tuned model
model = AutoModelForCausalLM.from_pretrained(
    "./functiongemma-myday-finetuned",
    torch_dtype=torch.float32
)

# Convert to TFLite
sample_input = torch.randint(0, 32000, (1, 512))

edge_model = ai_edge_torch.convert(
    model,
    sample_args=(sample_input,),
)

# Quantize to int8 for mobile
edge_model = ai_edge_torch.quantize(
    edge_model,
    quant_config=ai_edge_torch.QuantConfig.DYNAMIC_INT8
)

# Export
edge_model.export("./functiongemma-270m-finetuned.tflite")

print(f"Model size: {os.path.getsize('./functiongemma-270m-finetuned.tflite') / 1024 / 1024:.1f} MB")
```

---

## Voice Pipeline

### Voice Pipeline Service

```dart
// lib/services/voice_pipeline_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:riverpod/riverpod.dart';

enum VoiceState {
  idle,
  listening,
  processing,
  executing,
  complete,
  error,
}

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
    this.audioLevels = const [],
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

class VoicePipelineService extends StateNotifier<VoicePipelineState> {
  final LiteRTService _liteRT;
  final FunctionRouterService _router;
  final AudioRecorder _recorder = AudioRecorder();
  
  StreamSubscription? _audioSubscription;
  Timer? _silenceTimer;
  
  static const _sampleRate = 16000;
  static const _silenceTimeout = Duration(milliseconds: 1500);
  
  VoicePipelineService(this._liteRT, this._router) 
      : super(VoicePipelineState());
  
  Future<void> startListening() async {
    if (state.state == VoiceState.listening) return;
    
    state = state.copyWith(
      state: VoiceState.listening,
      transcript: null,
      intent: null,
      functionCall: null,
    );
    
    // Start recording
    final stream = await _recorder.startStream(RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
    ));
    
    final audioBuffer = <double>[];
    
    _audioSubscription = stream.listen((data) async {
      // Convert to float array
      final floatData = _bytesToFloats(data);
      audioBuffer.addAll(floatData);
      
      // Update audio levels for visualization
      state = state.copyWith(
        audioLevels: _calculateAudioLevels(floatData),
      );
      
      // Check for voice activity
      final hasVoice = await _liteRT.detectVoiceActivity(
        Float32List.fromList(floatData)
      );
      
      if (hasVoice) {
        _resetSilenceTimer();
        
        // Streaming transcription every 200ms of audio
        if (audioBuffer.length >= _sampleRate * 0.2) {
          _processPartialAudio(Float32List.fromList(audioBuffer));
        }
      } else {
        _startSilenceTimer(() => _finishListening(audioBuffer));
      }
    });
  }
  
  Future<void> _processPartialAudio(Float32List audio) async {
    final partial = await _liteRT.transcribePartial(audio);
    
    state = state.copyWith(
      transcript: partial.text,
      intent: partial.intent,
      confidence: partial.confidence,
    );
    
    // Speculative execution if high confidence
    if (partial.confidence > 0.9 && partial.intent != null) {
      _speculativeExecute(partial);
    }
  }
  
  Future<void> _finishListening(List<double> audioBuffer) async {
    await _recorder.stop();
    _audioSubscription?.cancel();
    
    state = state.copyWith(state: VoiceState.processing);
    
    try {
      // Final transcription
      final transcript = await _liteRT.transcribe(
        Float32List.fromList(audioBuffer)
      );
      
      state = state.copyWith(transcript: transcript);
      
      // Generate function call
      final functionCall = await _liteRT.generateFunctionCall(transcript);
      
      state = state.copyWith(
        state: VoiceState.executing,
        functionCall: functionCall,
      );
      
      // Execute function
      await _router.execute(functionCall);
      
      state = state.copyWith(state: VoiceState.complete);
      
      // Auto-reset after delay
      Future.delayed(Duration(seconds: 2), () {
        state = VoicePipelineState();
      });
      
    } catch (e) {
      state = state.copyWith(
        state: VoiceState.error,
        error: e.toString(),
      );
    }
  }
  
  void _speculativeExecute(PartialTranscript partial) {
    // Pre-warm the function router with predicted intent
    _router.prepareExecution(partial.intent!);
  }
  
  List<double> _bytesToFloats(Uint8List bytes) {
    final floats = <double>[];
    for (var i = 0; i < bytes.length - 1; i += 2) {
      final sample = bytes[i] | (bytes[i + 1] << 8);
      final signed = sample > 32767 ? sample - 65536 : sample;
      floats.add(signed / 32768.0);
    }
    return floats;
  }
  
  List<double> _calculateAudioLevels(List<double> samples) {
    const buckets = 24;
    final bucketSize = samples.length ~/ buckets;
    final levels = <double>[];
    
    for (var i = 0; i < buckets; i++) {
      final start = i * bucketSize;
      final end = start + bucketSize;
      final bucketSamples = samples.sublist(start, end.clamp(0, samples.length));
      
      final rms = bucketSamples.fold<double>(0, (sum, s) => sum + s * s);
      levels.add((rms / bucketSamples.length).clamp(0, 1));
    }
    
    return levels;
  }
  
  void _startSilenceTimer(VoidCallback onSilence) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, onSilence);
  }
  
  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
  }
  
  void cancel() {
    _recorder.stop();
    _audioSubscription?.cancel();
    _silenceTimer?.cancel();
    state = VoicePipelineState();
  }
  
  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}

// Provider
final voicePipelineProvider = StateNotifierProvider<VoicePipelineService, VoicePipelineState>((ref) {
  final liteRT = ref.watch(liteRTProvider);
  final router = ref.watch(functionRouterProvider);
  return VoicePipelineService(liteRT, router);
});
```

---

## Database Schema

### Drift Database

```dart
// lib/database/database.dart

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

// EVENTS TABLE
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get attendees => text().nullable()(); // JSON array
  TextColumn get color => text().withDefault(const Constant('blue'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// TASKS TABLE
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get dueTime => dateTime().nullable()();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  TextColumn get category => text().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get linkedEventId => integer().nullable().references(Events, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// NOTES TABLE
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text()();
  TextColumn get tags => text().nullable()(); // JSON array
  IntColumn get linkedEventId => integer().nullable().references(Events, #id)();
  IntColumn get linkedTaskId => integer().nullable().references(Tasks, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Events, Tasks, Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  @override
  int get schemaVersion => 1;
  
  // EVENT QUERIES
  Future<List<Event>> getEventsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(Duration(days: 1));
    
    return (select(events)
      ..where((e) => e.date.isBetweenValues(startOfDay, endOfDay))
      ..orderBy([(e) => OrderingTerm.asc(e.startTime)])
    ).get();
  }
  
  Future<int> insertEvent(EventsCompanion event) => into(events).insert(event);
  
  Future<Event?> findEventByRef(String ref) {
    return (select(events)
      ..where((e) => e.title.lower().contains(ref.toLowerCase()))
      ..limit(1)
    ).getSingleOrNull();
  }
  
  // TASK QUERIES
  Future<List<Task>> getTasksForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(Duration(days: 1));
    
    return (select(tasks)
      ..where((t) => t.dueDate.isBetweenValues(startOfDay, endOfDay) | t.dueDate.isNull())
      ..where((t) => t.completed.equals(false))
      ..orderBy([
        (t) => OrderingTerm.desc(t.priority),
        (t) => OrderingTerm.asc(t.dueTime),
      ])
    ).get();
  }
  
  Future<List<Task>> getPendingTasks() {
    return (select(tasks)
      ..where((t) => t.completed.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)])
    ).get();
  }
  
  Future<int> insertTask(TasksCompanion task) => into(tasks).insert(task);
  
  Future<bool> completeTask(int id) {
    return (update(tasks)..where((t) => t.id.equals(id)))
        .write(TasksCompanion(completed: Value(true)));
  }
  
  Future<Task?> findTaskByRef(String ref) {
    return (select(tasks)
      ..where((t) => t.title.lower().contains(ref.toLowerCase()))
      ..where((t) => t.completed.equals(false))
      ..limit(1)
    ).getSingleOrNull();
  }
  
  // NOTE QUERIES
  Future<List<Note>> getRecentNotes({int limit = 20}) {
    return (select(notes)
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
      ..limit(limit)
    ).get();
  }
  
  Future<List<Note>> searchNotes(String query) {
    return (select(notes)
      ..where((n) => n.content.lower().contains(query.toLowerCase()) |
                     n.title.lower().contains(query.toLowerCase()) |
                     n.tags.lower().contains(query.toLowerCase()))
    ).get();
  }
  
  Future<List<Note>> getNotesLinkedToEvent(int eventId) {
    return (select(notes)
      ..where((n) => n.linkedEventId.equals(eventId))
    ).get();
  }
  
  Future<List<Note>> getNotesLinkedToTask(int taskId) {
    return (select(notes)
      ..where((n) => n.linkedTaskId.equals(taskId))
    ).get();
  }
  
  Future<int> insertNote(NotesCompanion note) => into(notes).insert(note);
  
  // TIMELINE QUERY (combined view)
  Future<List<TimelineItem>> getTimelineForDate(DateTime date) async {
    final dayEvents = await getEventsForDate(date);
    final dayTasks = await getTasksForDate(date);
    
    final items = <TimelineItem>[];
    
    for (final event in dayEvents) {
      final linkedNotes = await getNotesLinkedToEvent(event.id);
      items.add(TimelineItem.event(event, linkedNotes));
    }
    
    for (final task in dayTasks) {
      final linkedNotes = await getNotesLinkedToTask(task.id);
      items.add(TimelineItem.task(task, linkedNotes));
    }
    
    items.sort((a, b) => a.sortTime.compareTo(b.sortTime));
    return items;
  }
}

class TimelineItem {
  final String type;
  final dynamic item;
  final List<Note> linkedNotes;
  final DateTime sortTime;
  
  TimelineItem._({
    required this.type,
    required this.item,
    required this.linkedNotes,
    required this.sortTime,
  });
  
  factory TimelineItem.event(Event event, List<Note> notes) {
    return TimelineItem._(
      type: 'event',
      item: event,
      linkedNotes: notes,
      sortTime: event.startTime,
    );
  }
  
  factory TimelineItem.task(Task task, List<Note> notes) {
    return TimelineItem._(
      type: 'task',
      item: task,
      linkedNotes: notes,
      sortTime: task.dueTime ?? DateTime(2099), // Tasks without time go last
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'myday.sqlite'));
    return NativeDatabase(file);
  });
}
```

---

## Flutter Implementation

### Function Router Service

```dart
// lib/services/function_router_service.dart

import 'package:riverpod/riverpod.dart';
import '../database/database.dart';

class FunctionRouterService {
  final AppDatabase _db;
  
  FunctionRouterService(this._db);
  
  Future<ExecutionResult> execute(FunctionCall call) async {
    switch (call.name) {
      // SCHEDULE
      case 'add_event':
        return _addEvent(call.parameters);
      case 'reschedule_event':
        return _rescheduleEvent(call.parameters);
      case 'cancel_event':
        return _cancelEvent(call.parameters);
      
      // TASKS
      case 'add_task':
        return _addTask(call.parameters);
      case 'complete_task':
        return _completeTask(call.parameters);
      case 'defer_task':
        return _deferTask(call.parameters);
      
      // NOTES
      case 'create_note':
        return _createNote(call.parameters);
      case 'append_note':
        return _appendNote(call.parameters);
      case 'search_notes':
        return _searchNotes(call.parameters);
      
      // QUERIES
      case 'list_today':
        return _listToday(call.parameters);
      case 'search_all':
        return _searchAll(call.parameters);
      
      default:
        return ExecutionResult.error('Unknown function: ${call.name}');
    }
  }
  
  Future<ExecutionResult> _addEvent(Map<String, dynamic> params) async {
    final date = _parseDate(params['date'] as String);
    final startTime = _parseTime(params['start_time'] as String, date);
    final endTime = params['end_time'] != null 
        ? _parseTime(params['end_time'] as String, date)
        : null;
    
    final id = await _db.insertEvent(EventsCompanion.insert(
      title: params['title'] as String,
      date: date,
      startTime: startTime,
      endTime: Value(endTime),
      location: Value(params['location'] as String?),
      attendees: Value(params['attendees'] != null 
          ? jsonEncode(params['attendees']) 
          : null),
    ));
    
    return ExecutionResult.success(
      'Event created',
      data: {'id': id, 'type': 'event'},
    );
  }
  
  Future<ExecutionResult> _addTask(Map<String, dynamic> params) async {
    final dueDate = params['due_date'] != null 
        ? _parseDate(params['due_date'] as String)
        : null;
    
    int? linkedEventId;
    if (params['linked_event'] != null) {
      final event = await _db.findEventByRef(params['linked_event'] as String);
      linkedEventId = event?.id;
    }
    
    final id = await _db.insertTask(TasksCompanion.insert(
      title: params['title'] as String,
      dueDate: Value(dueDate),
      priority: Value(params['priority'] as String? ?? 'medium'),
      category: Value(params['category'] as String?),
      linkedEventId: Value(linkedEventId),
    ));
    
    return ExecutionResult.success(
      'Task created',
      data: {'id': id, 'type': 'task'},
    );
  }
  
  Future<ExecutionResult> _completeTask(Map<String, dynamic> params) async {
    final task = await _db.findTaskByRef(params['task_ref'] as String);
    if (task == null) {
      return ExecutionResult.error('Task not found');
    }
    
    await _db.completeTask(task.id);
    return ExecutionResult.success('Task completed');
  }
  
  Future<ExecutionResult> _createNote(Map<String, dynamic> params) async {
    int? linkedEventId;
    int? linkedTaskId;
    
    if (params['linked_event'] != null) {
      final event = await _db.findEventByRef(params['linked_event'] as String);
      linkedEventId = event?.id;
    }
    
    if (params['linked_task'] != null) {
      final task = await _db.findTaskByRef(params['linked_task'] as String);
      linkedTaskId = task?.id;
    }
    
    final id = await _db.insertNote(NotesCompanion.insert(
      title: Value(params['title'] as String?),
      content: params['content'] as String,
      tags: Value(params['tags'] != null ? jsonEncode(params['tags']) : null),
      linkedEventId: Value(linkedEventId),
      linkedTaskId: Value(linkedTaskId),
    ));
    
    return ExecutionResult.success(
      'Note created',
      data: {'id': id, 'type': 'note'},
    );
  }
  
  Future<ExecutionResult> _listToday(Map<String, dynamic> params) async {
    final timeline = await _db.getTimelineForDate(DateTime.now());
    return ExecutionResult.success(
      'Timeline loaded',
      data: {'items': timeline},
    );
  }
  
  DateTime _parseDate(String input) {
    final lower = input.toLowerCase();
    final now = DateTime.now();
    
    if (lower == 'today') return now;
    if (lower == 'tomorrow') return now.add(Duration(days: 1));
    if (lower == 'yesterday') return now.subtract(Duration(days: 1));
    
    // Day of week
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayIndex = days.indexOf(lower);
    if (dayIndex >= 0) {
      var target = dayIndex + 1;
      var current = now.weekday;
      var diff = target - current;
      if (diff <= 0) diff += 7;
      return now.add(Duration(days: diff));
    }
    
    // Try parsing as date
    return DateTime.tryParse(input) ?? now;
  }
  
  DateTime _parseTime(String input, DateTime date) {
    final match = RegExp(r'(\d{1,2}):?(\d{2})?\s*(am|pm)?', caseSensitive: false)
        .firstMatch(input);
    
    if (match != null) {
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2) ?? '0');
      final period = match.group(3)?.toLowerCase();
      
      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;
      
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    
    return date;
  }
  
  // Pre-warm for speculative execution
  void prepareExecution(String intent) {
    // Could pre-fetch relevant data based on intent
  }
}

class ExecutionResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  
  ExecutionResult._({
    required this.success,
    required this.message,
    this.data,
  });
  
  factory ExecutionResult.success(String message, {Map<String, dynamic>? data}) {
    return ExecutionResult._(success: true, message: message, data: data);
  }
  
  factory ExecutionResult.error(String message) {
    return ExecutionResult._(success: false, message: message);
  }
}
```

### Providers

```dart
// lib/providers/providers.dart

import 'package:riverpod/riverpod.dart';
import '../database/database.dart';
import '../services/litert_service.dart';
import '../services/function_router_service.dart';
import '../services/voice_pipeline_service.dart';

// Database
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// LiteRT
final liteRTProvider = Provider<LiteRTService>((ref) {
  final service = LiteRTService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Function Router
final functionRouterProvider = Provider<FunctionRouterService>((ref) {
  final db = ref.watch(databaseProvider);
  return FunctionRouterService(db);
});

// Voice Pipeline
final voicePipelineProvider = StateNotifierProvider<VoicePipelineService, VoicePipelineState>((ref) {
  final liteRT = ref.watch(liteRTProvider);
  final router = ref.watch(functionRouterProvider);
  return VoicePipelineService(liteRT, router);
});

// Timeline
final timelineProvider = StreamProvider.family<List<TimelineItem>, DateTime>((ref, date) {
  final db = ref.watch(databaseProvider);
  // Return stream that updates on database changes
  return Stream.periodic(Duration(seconds: 1)).asyncMap((_) => db.getTimelineForDate(date));
});

// Active View
final activeViewProvider = StateProvider<String>((ref) => 'timeline');

// Selected Date
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
```

---

## UI Components

### Project Structure

```
lib/
├── main.dart
├── app.dart
├── database/
│   ├── database.dart
│   └── database.g.dart
├── models/
│   ├── event.dart
│   ├── task.dart
│   ├── note.dart
│   └── timeline_item.dart
├── providers/
│   └── providers.dart
├── services/
│   ├── litert_service.dart
│   ├── voice_pipeline_service.dart
│   ├── function_router_service.dart
│   └── proactive_service.dart
├── ui/
│   ├── screens/
│   │   └── home_screen.dart
│   ├── widgets/
│   │   ├── voice_widget.dart
│   │   ├── timeline_view.dart
│   │   ├── schedule_view.dart
│   │   ├── tasks_view.dart
│   │   ├── notes_view.dart
│   │   ├── event_card.dart
│   │   ├── task_card.dart
│   │   ├── note_card.dart
│   │   ├── ghost_card.dart
│   │   └── waveform_visualizer.dart
│   └── theme/
│       └── app_theme.dart
└── utils/
    ├── date_utils.dart
    └── audio_utils.dart

android/
├── app/
│   ├── src/main/
│   │   ├── kotlin/com/example/myday/
│   │   │   ├── MainActivity.kt
│   │   │   ├── LiteRTBridge.kt
│   │   │   └── LiteRTPlugin.kt
│   │   └── assets/models/
│   │       ├── silero_vad.tflite
│   │       ├── whisper-tiny.tflite
│   │       └── functiongemma-270m-finetuned.tflite
│   └── build.gradle
└── build.gradle

ios/
├── Runner/
│   ├── AppDelegate.swift
│   ├── LiteRTBridge.swift
│   └── Models/
│       ├── silero_vad.tflite
│       ├── whisper-tiny.tflite
│       └── functiongemma-270m-finetuned.tflite
└── Podfile
```

### Voice Widget

```dart
// lib/ui/widgets/voice_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import 'waveform_visualizer.dart';
import 'ghost_card.dart';

class VoiceWidget extends ConsumerWidget {
  const VoiceWidget({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voicePipelineProvider);
    final isListening = state.state == VoiceState.listening;
    final isProcessing = state.state == VoiceState.processing;
    
    return Column(
      children: [
        // Voice Input Area
        GestureDetector(
          onTap: () {
            if (state.state == VoiceState.idle) {
              ref.read(voicePipelineProvider.notifier).startListening();
            }
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.all(isListening ? 16 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isListening 
                  ? Colors.purple.withOpacity(0.1)
                  : Colors.grey.shade900,
              border: Border.all(
                color: isListening 
                    ? Colors.purple.withOpacity(0.3)
                    : Colors.grey.shade800,
              ),
            ),
            child: isListening || isProcessing
                ? _buildListeningState(state)
                : _buildIdleState(),
          ),
        ),
        
        // Ghost Card (Speculative Preview)
        if (state.intent != null && state.confidence != null && state.confidence! > 0.8)
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: GhostCard(
              intent: state.intent!,
              transcript: state.transcript ?? '',
              confidence: state.confidence!,
            ),
          ),
        
        // Confirmation
        if (state.state == VoiceState.complete)
          _buildConfirmation(state),
      ],
    );
  }
  
  Widget _buildIdleState() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.pink],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.mic, color: Colors.white, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tap to speak', style: TextStyle(color: Colors.grey.shade300)),
              Text(
                '"Schedule...", "Remind me...", "Note..."',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        Text('~400ms', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
      ],
    );
  }
  
  Widget _buildListeningState(VoicePipelineState state) {
    return Column(
      children: [
        // Waveform
        SizedBox(
          height: 48,
          child: WaveformVisualizer(levels: state.audioLevels),
        ),
        SizedBox(height: 12),
        
        // Transcript
        if (state.transcript != null)
          Text(
            state.transcript!,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        
        // Intent Badge
        if (state.intent != null)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getIntentColor(state.intent!).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.intent} (${(state.confidence! * 100).toInt()}%)',
                style: TextStyle(
                  color: _getIntentColor(state.intent!),
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildConfirmation(VoicePipelineState state) {
    return Container(
      margin: EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.check, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Done!', style: TextStyle(color: Colors.green.shade200)),
                Text(
                  state.functionCall?.name ?? '',
                  style: TextStyle(color: Colors.green.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getIntentColor(String intent) {
    switch (intent) {
      case 'add_event':
      case 'reschedule_event':
      case 'cancel_event':
        return Colors.blue;
      case 'add_task':
      case 'complete_task':
      case 'defer_task':
        return Colors.amber;
      case 'create_note':
      case 'append_note':
      case 'search_notes':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
```

### Home Screen

```dart
// lib/ui/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../widgets/voice_widget.dart';
import '../widgets/timeline_view.dart';
import '../widgets/schedule_view.dart';
import '../widgets/tasks_view.dart';
import '../widgets/notes_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeView = ref.watch(activeViewProvider);
    
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, ref),
            
            // View Tabs
            _buildTabs(ref, activeView),
            
            // Voice Widget
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: VoiceWidget(),
            ),
            
            // Content
            Expanded(
              child: _buildContent(activeView),
            ),
            
            // Quick Actions
            _buildQuickActions(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Day',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
              ),
              Text(
                _formatDate(DateTime.now()),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'NPU Active',
                  style: TextStyle(color: Colors.green, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabs(WidgetRef ref, String activeView) {
    final tabs = [
      ('timeline', 'Timeline', '◉'),
      ('schedule', 'Schedule', '📅'),
      ('tasks', 'Tasks', '☑'),
      ('notes', 'Notes', '📝'),
    ];
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isActive = activeView == tab.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(activeViewProvider.notifier).state = tab.$1,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey.shade800 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${tab.$3} ${tab.$2}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildContent(String activeView) {
    switch (activeView) {
      case 'timeline':
        return TimelineView();
      case 'schedule':
        return ScheduleView();
      case 'tasks':
        return TasksView();
      case 'notes':
        return NotesView();
      default:
        return TimelineView();
    }
  }
  
  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _quickActionButton('+ Event', Colors.blue),
          SizedBox(width: 12),
          _quickActionButton('+ Task', Colors.amber),
          SizedBox(width: 12),
          _quickActionButton('+ Note', Colors.purple),
        ],
      ),
    );
  }
  
  Widget _quickActionButton(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}
```

---

## Build & Deployment

### Model Preparation

```bash
# 1. Fine-tune FunctionGemma
cd training
python finetune_functiongemma.py

# 2. Convert to TFLite
python convert_to_tflite.py

# 3. Convert Whisper to TFLite
# Use whisper.cpp or OpenAI's conversion tools
python convert_whisper_tflite.py --model tiny

# 4. Copy models to assets
cp functiongemma-270m-finetuned.tflite ../android/app/src/main/assets/models/
cp whisper-tiny.tflite ../android/app/src/main/assets/models/
cp silero_vad.tflite ../android/app/src/main/assets/models/
```

### Android Build

```bash
# Debug
flutter run --debug

# Release with NPU support
flutter build apk --release

# Test on device with profiling
flutter run --profile --trace-systrace
```

### iOS Build

```bash
# Pod install
cd ios && pod install && cd ..

# Debug
flutter run --debug

# Release
flutter build ios --release
```

### Performance Testing

```dart
// lib/utils/performance_test.dart

class PerformanceTest {
  final LiteRTService _liteRT;
  
  Future<void> runBenchmark() async {
    // Whisper latency
    final whisperStart = DateTime.now();
    await _liteRT.transcribe(testAudio);
    final whisperLatency = DateTime.now().difference(whisperStart);
    print('Whisper latency: ${whisperLatency.inMilliseconds}ms');
    
    // FunctionGemma latency
    final gemmaStart = DateTime.now();
    await _liteRT.generateFunctionCall('Add dentist tomorrow at 2pm');
    final gemmaLatency = DateTime.now().difference(gemmaStart);
    print('FunctionGemma latency: ${gemmaLatency.inMilliseconds}ms');
    
    // End-to-end
    final e2eStart = DateTime.now();
    // Full pipeline...
    final e2eLatency = DateTime.now().difference(e2eStart);
    print('End-to-end latency: ${e2eLatency.inMilliseconds}ms');
  }
}
```

---

## Checklist

### Phase 1: Foundation
- [ ] Set up Flutter project structure
- [ ] Implement Drift database
- [ ] Create basic UI screens
- [ ] Add native LiteRT bridges (Android/iOS)

### Phase 2: Models
- [ ] Fine-tune FunctionGemma on My Day schema
- [ ] Convert models to TFLite
- [ ] Test inference on device
- [ ] Optimize quantization

### Phase 3: Voice Pipeline
- [ ] Implement audio recording
- [ ] Add VAD integration
- [ ] Set up streaming transcription
- [ ] Implement speculative execution

### Phase 4: Integration
- [ ] Connect voice → function router → database
- [ ] Add UI feedback (ghost cards, confirmations)
- [ ] Implement proactive suggestions
- [ ] Performance optimization

### Phase 5: Polish
- [ ] Haptic feedback
- [ ] Audio cues
- [ ] Error handling
- [ ] Edge case testing

---

## Resources

- [LiteRT Documentation](https://ai.google.dev/edge/litert)
- [FunctionGemma Model](https://huggingface.co/google/functiongemma-270m-it)
- [LiteRT GitHub](https://github.com/google-ai-edge/LiteRT)
- [Whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- [Silero VAD](https://github.com/snakers4/silero-vad)