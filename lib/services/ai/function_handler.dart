import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:my_day/data/models/task_model.dart';
import 'package:my_day/data/models/event_model.dart';
import 'package:my_day/data/models/note_model.dart';
import 'package:my_day/data/sources/database_helper.dart';

/// Result of a function execution
class FunctionResult {
  final String functionName;
  final bool success;
  final Map<String, dynamic> data;
  final String? error;

  FunctionResult({
    required this.functionName,
    required this.success,
    this.data = const {},
    this.error,
  });

  factory FunctionResult.success(String name, Map<String, dynamic> data) {
    return FunctionResult(functionName: name, success: true, data: data);
  }

  factory FunctionResult.failure(String name, String error) {
    return FunctionResult(functionName: name, success: false, error: error);
  }
}

class FunctionHandler {
  final DatabaseHelper _db;
  final Uuid _uuid = const Uuid();

  FunctionHandler(this._db);

  /// Execute a function and return structured result for response generation
  Future<FunctionResult> handleExecution(String jsonString) async {
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
        return FunctionResult.failure('unknown', 'Invalid function call structure');
      }

      switch (functionName) {
        case 'create_task':
          return await _createTask(arguments);
        case 'create_event':
          return await _createEvent(arguments);
        case 'create_note':
          return await _createNote(arguments);
        case 'get_tasks':
          return await _getTasks(arguments);
        case 'get_events':
          return await _getEvents(arguments);
        case 'get_schedule':
          return await _getSchedule();
        default:
          return FunctionResult.failure(functionName, 'Unknown function: $functionName');
      }
    } catch (e) {
      print("Error executing function: $e");
      return FunctionResult.failure('unknown', e.toString());
    }
  }

  Future<FunctionResult> _createTask(Map<String, dynamic> args) async {
    final title = args['title'] ?? 'New Task';
    final priorityStr = args['priority'] ?? 'medium';
    final dueDateStr = args['due_date'];

    TaskPriority priority;
    switch (priorityStr.toString().toLowerCase()) {
      case 'high': priority = TaskPriority.high; break;
      case 'low': priority = TaskPriority.low; break;
      default: priority = TaskPriority.medium;
    }

    DateTime? dueDate;
    if (dueDateStr != null) {
      dueDate = DateTime.tryParse(dueDateStr);
    }

    final task = TaskModel(
      id: _uuid.v4(),
      title: title,
      priority: priority,
      createdAt: DateTime.now(),
      dueDate: dueDate,
    );
    
    await _db.createTask(task);

    return FunctionResult.success('create_task', {
      'title': title,
      'priority': priorityStr,
      'dueDate': dueDate?.toIso8601String(),
    });
  }

  Future<FunctionResult> _createEvent(Map<String, dynamic> args) async {
    final title = args['title'] ?? 'New Event';
    final startTimeStr = args['start_time'];
    final duration = args['duration_minutes'] ?? 30;

    final DateTime startTime = DateTime.tryParse(startTimeStr ?? '') ?? DateTime.now();
    final DateTime date = DateTime(startTime.year, startTime.month, startTime.day);
    final DateTime? endTime = startTime.add(Duration(minutes: duration));
    final event = EventModel(
      id: _uuid.v4(),
      title: title,
      date: date,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: duration,
    );

    await _db.createEvent(event);

    return FunctionResult.success('create_event', {
      'title': title,
      'startTime': startTime.toIso8601String(),
      'durationMinutes': duration,
    });
  }

  Future<FunctionResult> _createNote(Map<String, dynamic> args) async {
    final title = args['title'] ?? 'New Note';
    final content = args['content'] ?? '';
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

    return FunctionResult.success('create_note', {
      'title': title,
      'tags': tags,
    });
  }

  // ========== Query Functions ==========

  Future<FunctionResult> _getTasks(Map<String, dynamic> args) async {
    try {
      final tasks = await _db.getAllTasks();
      final filter = args['filter'] ?? 'all'; // all, pending, completed, high

      List<TaskModel> filtered = tasks;
      
      if (filter == 'pending') {
        filtered = tasks.where((t) => !t.isCompleted).toList();
      } else if (filter == 'completed') {
        filtered = tasks.where((t) => t.isCompleted).toList();
      } else if (filter == 'high') {
        filtered = tasks.where((t) => t.priority == TaskPriority.high && !t.isCompleted).toList();
      }

      final highPriority = tasks.where((t) => t.priority == TaskPriority.high && !t.isCompleted).length;
      final completed = tasks.where((t) => t.isCompleted).length;

      return FunctionResult.success('get_tasks', {
        'total': tasks.length,
        'pending': tasks.length - completed,
        'completed': completed,
        'highPriority': highPriority,
        'topTasks': filtered.take(5).map((t) => t.title).toList(),
      });
    } catch (e) {
      return FunctionResult.failure('get_tasks', e.toString());
    }
  }

  Future<FunctionResult> _getEvents(Map<String, dynamic> args) async {
    try {
      final events = await _db.getAllEvents();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Filter today's events
      final todayEvents = events.where((e) {
        final eventDay = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
        return eventDay == today;
      }).toList();

      // Sort by time
      todayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Find next upcoming event
      final upcoming = todayEvents.where((e) => e.startTime.isAfter(now)).toList();
      
      return FunctionResult.success('get_events', {
        'total': events.length,
        'todayCount': todayEvents.length,
        'upcomingToday': upcoming.length,
        'nextEvent': upcoming.isNotEmpty ? upcoming.first.title : null,
        'nextEventTime': upcoming.isNotEmpty ? upcoming.first.startTime.toIso8601String() : null,
        'todayEvents': todayEvents.map((e) => {
          'title': e.title, 
          'time': e.startTime.toIso8601String()
        }).toList(),
      });
    } catch (e) {
      return FunctionResult.failure('get_events', e.toString());
    }
  }

  Future<FunctionResult> _getSchedule() async {
    try {
      final tasksResult = await _getTasks({});
      final eventsResult = await _getEvents({});

      return FunctionResult.success('get_schedule', {
        'tasks': tasksResult.data,
        'events': eventsResult.data,
      });
    } catch (e) {
      return FunctionResult.failure('get_schedule', e.toString());
    }
  }
}
