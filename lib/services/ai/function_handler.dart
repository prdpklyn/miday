
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:my_day/data/models/task_model.dart';
import 'package:my_day/data/models/event_model.dart';
import 'package:my_day/data/models/note_model.dart';
import 'package:my_day/data/sources/database_helper.dart';

class FunctionHandler {
  final DatabaseHelper _db;
  final Uuid _uuid = const Uuid();

  FunctionHandler(this._db);

  Future<void> handleExecution(String jsonString) async {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);
      
      // Handle both "function_call" wrapper or direct name/arguments structure
      String? functionName;
      Map<String, dynamic>? arguments;

      if (data.containsKey('name') && data.containsKey('arguments')) {
        functionName = data['name'];
        arguments = data['arguments'] is String 
            ? json.decode(data['arguments']) 
            : data['arguments'];
      }

      if (functionName == null || arguments == null) {
          print("Invalid function call structure");
          return;
      }

      switch (functionName) {
        case 'create_task':
          await _createTask(arguments);
          break;
        case 'create_event':
          await _createEvent(arguments);
          break;
        case 'create_note':
          await _createNote(arguments);
          break;
        default:
          print("Unknown function: $functionName");
      }
    } catch (e) {
      print("Error executing function: $e");
    }
  }

  Future<void> _createTask(Map<String, dynamic> args) async {
    final title = args['title'];
    final priorityStr = args['priority'] ?? 'medium';
    final dueDateStr = args['due_date'];

    TaskPriority priority;
    switch (priorityStr.toString().toLowerCase()) {
      case 'high': priority = TaskPriority.high; break;
      case 'low': priority = TaskPriority.low; break;
      default: priority = TaskPriority.medium;
    }

    final task = TaskModel(
      id: _uuid.v4(),
      title: title,
      priority: priority,
      createdAt: DateTime.now(),
      dueDate: dueDateStr != null ? DateTime.tryParse(dueDateStr) : null,
    );
    
    await _db.createTask(task);
  }

  Future<void> _createEvent(Map<String, dynamic> args) async {
    final title = args['title'];
    final startTimeStr = args['start_time'];
    final duration = args['duration_minutes'] ?? 30;

    final event = EventModel(
      id: _uuid.v4(),
      title: title,
      startTime: DateTime.tryParse(startTimeStr) ?? DateTime.now(),
      durationMinutes: duration,
    );

    await _db.createEvent(event);
  }

  Future<void> _createNote(Map<String, dynamic> args) async {
    final title = args['title'] ?? 'New Note';
    final content = args['content'];
    final tagsList = args['tags'] as List<dynamic>?;
    final tags = tagsList?.map((e) => e.toString()).toList() ?? [];

    final note = NoteModel(
      id: _uuid.v4(),
      title: title,
      content: content,
      tags: tags,
      createdAt: DateTime.now(),
    );

    await _db.createNote(note);
  }
}
