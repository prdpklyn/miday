import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:my_day/data/sources/app_database.dart';
import 'package:my_day/services/litert_service.dart';
import 'package:uuid/uuid.dart';

class FunctionRouterService {
  FunctionRouterService(this._db);
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();
  void prepareExecution(String intent) {
  }
  Future<ExecutionResult> execute(FunctionCall call) async {
    switch (call.name) {
      case 'add_event':
        return _addEvent(call.parameters);
      case 'reschedule_event':
        return _rescheduleEvent(call.parameters);
      case 'cancel_event':
        return _cancelEvent(call.parameters);
      case 'add_task':
        return _addTask(call.parameters);
      case 'complete_task':
        return _completeTask(call.parameters);
      case 'defer_task':
        return _deferTask(call.parameters);
      case 'create_note':
        return _createNote(call.parameters);
      case 'append_note':
        return _appendNote(call.parameters);
      case 'search_notes':
        return _searchNotes(call.parameters);
      case 'list_today':
        return _listToday(call.parameters);
      case 'search_all':
        return _searchAll(call.parameters);
      default:
        return ExecutionResult.error('Unknown function: ${call.name}');
    }
  }
  Future<ExecutionResult> _addEvent(Map<String, dynamic> params) async {
    final String title = params['title'] as String? ?? 'Untitled event';
    final DateTime date = _parseDate(params['date'] as String? ?? 'today');
    final DateTime startTime = _parseTime(params['start_time'] as String? ?? '09:00', date);
    final DateTime? endTime = params['end_time'] == null ? null : _parseTime(params['end_time'] as String, date);
    final String id = _uuid.v4();
    await _db.insertEvent(EventsCompanion.insert(
      id: id,
      title: title,
      date: date,
      startTime: startTime,
      endTime: Value(endTime),
      location: Value(params['location'] as String?),
      attendees: Value(params['attendees'] == null ? null : jsonEncode(params['attendees'])),
      color: const Value('blue'),
    ));
    return ExecutionResult.success('Event created', data: <String, dynamic>{'id': id, 'type': 'event'});
  }
  Future<ExecutionResult> _rescheduleEvent(Map<String, dynamic> params) async {
    final String ref = params['event_ref'] as String? ?? '';
    final Event? event = await _findEventByRef(ref);
    if (event == null) return ExecutionResult.error('Event not found');
    final DateTime date = params['new_date'] == null ? event.date : _parseDate(params['new_date'] as String);
    final DateTime startTime = params['new_time'] == null ? event.startTime : _parseTime(params['new_time'] as String, date);
    final EventsCompanion update = EventsCompanion(
      date: Value(date),
      startTime: Value(startTime),
      updatedAt: Value(DateTime.now()),
    );
    await (_db.update(_db.events)..where((Events e) => e.id.equals(event.id))).write(update);
    return ExecutionResult.success('Event rescheduled', data: <String, dynamic>{'id': event.id});
  }
  Future<ExecutionResult> _cancelEvent(Map<String, dynamic> params) async {
    final String ref = params['event_ref'] as String? ?? '';
    final Event? event = await _findEventByRef(ref);
    if (event == null) return ExecutionResult.error('Event not found');
    await (_db.delete(_db.events)..where((Events e) => e.id.equals(event.id))).go();
    return ExecutionResult.success('Event cancelled', data: <String, dynamic>{'id': event.id});
  }
  Future<ExecutionResult> _addTask(Map<String, dynamic> params) async {
    final String title = params['title'] as String? ?? 'Untitled task';
    final DateTime? dueDate = params['due_date'] == null ? null : _parseDate(params['due_date'] as String);
    final DateTime? dueTime = params['due_time'] == null || dueDate == null ? null : _parseTime(params['due_time'] as String, dueDate);
    final String priority = params['priority'] as String? ?? 'medium';
    final String? category = params['category'] as String?;
    final String id = _uuid.v4();
    String? linkedEventId;
    if (params['linked_event'] != null) {
      final Event? event = await _findEventByRef(params['linked_event'] as String);
      linkedEventId = event?.id;
    }
    await _db.insertTask(TasksCompanion.insert(
      id: id,
      title: title,
      dueDate: Value(dueDate),
      dueTime: Value(dueTime),
      priority: Value(priority),
      category: Value(category),
      completed: const Value(false),
      linkedEventId: Value(linkedEventId),
    ));
    return ExecutionResult.success('Task created', data: <String, dynamic>{'id': id, 'type': 'task'});
  }
  Future<ExecutionResult> _completeTask(Map<String, dynamic> params) async {
    final String ref = params['task_ref'] as String? ?? '';
    final Task? task = await _findTaskByRef(ref);
    if (task == null) return ExecutionResult.error('Task not found');
    await (_db.update(_db.tasks)..where((Tasks t) => t.id.equals(task.id))).write(const TasksCompanion(completed: Value(true)));
    return ExecutionResult.success('Task completed', data: <String, dynamic>{'id': task.id});
  }
  Future<ExecutionResult> _deferTask(Map<String, dynamic> params) async {
    final String ref = params['task_ref'] as String? ?? '';
    final Task? task = await _findTaskByRef(ref);
    if (task == null) return ExecutionResult.error('Task not found');
    final DateTime newDate = _parseDate(params['new_date'] as String? ?? 'today');
    await (_db.update(_db.tasks)..where((Tasks t) => t.id.equals(task.id))).write(TasksCompanion(dueDate: Value(newDate)));
    return ExecutionResult.success('Task deferred', data: <String, dynamic>{'id': task.id});
  }
  Future<ExecutionResult> _createNote(Map<String, dynamic> params) async {
    final String content = params['content'] as String? ?? '';
    final String? title = params['title'] as String?;
    final List<dynamic>? tags = params['tags'] as List<dynamic>?;
    String? linkedEventId;
    String? linkedTaskId;
    if (params['linked_event'] != null) {
      final Event? event = await _findEventByRef(params['linked_event'] as String);
      linkedEventId = event?.id;
    }
    if (params['linked_task'] != null) {
      final Task? task = await _findTaskByRef(params['linked_task'] as String);
      linkedTaskId = task?.id;
    }
    final String id = _uuid.v4();
    await _db.insertNote(NotesCompanion.insert(
      id: id,
      title: Value(title),
      content: content,
      tags: Value(tags == null ? null : tags.join(',')),
      linkedEventId: Value(linkedEventId),
      linkedTaskId: Value(linkedTaskId),
    ));
    return ExecutionResult.success('Note created', data: <String, dynamic>{'id': id, 'type': 'note'});
  }
  Future<ExecutionResult> _appendNote(Map<String, dynamic> params) async {
    final String ref = params['note_ref'] as String? ?? '';
    final Note? note = await _findNoteByRef(ref);
    if (note == null) return ExecutionResult.error('Note not found');
    final String content = params['content'] as String? ?? '';
    final String updatedContent = '${note.content}\n$content'.trim();
    await (_db.update(_db.notes)..where((Notes n) => n.id.equals(note.id))).write(NotesCompanion(content: Value(updatedContent), updatedAt: Value(DateTime.now())));
    return ExecutionResult.success('Note updated', data: <String, dynamic>{'id': note.id});
  }
  Future<ExecutionResult> _searchNotes(Map<String, dynamic> params) async {
    final String query = params['query'] as String? ?? '';
    final List<Note> notes = await _db.searchNotes(query);
    return ExecutionResult.success('Notes found', data: <String, dynamic>{'items': notes});
  }
  Future<ExecutionResult> _listToday(Map<String, dynamic> params) async {
    final List<TimelineItem> timeline = await _db.getTimelineForDate(DateTime.now());
    return ExecutionResult.success('Timeline loaded', data: <String, dynamic>{'items': timeline});
  }
  Future<ExecutionResult> _searchAll(Map<String, dynamic> params) async {
    final String query = params['query'] as String? ?? '';
    final List<Event> events = await _searchEvents(query);
    final List<Task> tasks = await _searchTasks(query);
    final List<Note> notes = await _db.searchNotes(query);
    return ExecutionResult.success('Search complete', data: <String, dynamic>{'events': events, 'tasks': tasks, 'notes': notes});
  }
  Future<Event?> _findEventByRef(String ref) async {
    final String pattern = '%${ref.toLowerCase()}%';
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT * FROM events WHERE lower(title) LIKE ? LIMIT 1',
      variables: <Variable<Object>>[Variable<String>(pattern)],
      readsFrom: {_db.events},
    ).get();
    final List<Event> events = await Future.wait(rows.map((QueryRow row) => _db.events.mapFromRow(row)));
    return events.isEmpty ? null : events.first;
  }
  Future<Task?> _findTaskByRef(String ref) async {
    final String pattern = '%${ref.toLowerCase()}%';
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT * FROM tasks WHERE lower(title) LIKE ? AND completed = 0 LIMIT 1',
      variables: <Variable<Object>>[Variable<String>(pattern)],
      readsFrom: {_db.tasks},
    ).get();
    final List<Task> tasks = await Future.wait(rows.map((QueryRow row) => _db.tasks.mapFromRow(row)));
    return tasks.isEmpty ? null : tasks.first;
  }
  Future<Note?> _findNoteByRef(String ref) async {
    final String pattern = '%${ref.toLowerCase()}%';
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT * FROM notes WHERE lower(content) LIKE ? OR lower(COALESCE(title, "")) LIKE ? LIMIT 1',
      variables: <Variable<Object>>[Variable<String>(pattern), Variable<String>(pattern)],
      readsFrom: {_db.notes},
    ).get();
    final List<Note> notes = await Future.wait(rows.map((QueryRow row) => _db.notes.mapFromRow(row)));
    return notes.isEmpty ? null : notes.first;
  }
  Future<List<Event>> _searchEvents(String query) async {
    final String pattern = '%${query.toLowerCase()}%';
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT * FROM events WHERE lower(title) LIKE ?',
      variables: <Variable<Object>>[Variable<String>(pattern)],
      readsFrom: {_db.events},
    ).get();
    return Future.wait(rows.map((QueryRow row) => _db.events.mapFromRow(row)));
  }
  Future<List<Task>> _searchTasks(String query) async {
    final String pattern = '%${query.toLowerCase()}%';
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT * FROM tasks WHERE lower(title) LIKE ?',
      variables: <Variable<Object>>[Variable<String>(pattern)],
      readsFrom: {_db.tasks},
    ).get();
    return Future.wait(rows.map((QueryRow row) => _db.tasks.mapFromRow(row)));
  }
  DateTime _parseDate(String input) {
    final String lower = input.toLowerCase();
    final DateTime now = DateTime.now();
    if (lower == 'today') return now;
    if (lower == 'tomorrow') return now.add(const Duration(days: 1));
    if (lower == 'yesterday') return now.subtract(const Duration(days: 1));
    final List<String> days = <String>['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final int dayIndex = days.indexOf(lower);
    if (dayIndex >= 0) {
      final int target = dayIndex + 1;
      final int current = now.weekday;
      int diff = target - current;
      if (diff <= 0) diff += 7;
      return now.add(Duration(days: diff));
    }
    return DateTime.tryParse(input) ?? now;
  }
  DateTime _parseTime(String input, DateTime date) {
    final RegExpMatch? match = RegExp(r'(\d{1,2}):?(\d{2})?\s*(am|pm)?', caseSensitive: false).firstMatch(input);
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      final int minute = int.parse(match.group(2) ?? '0');
      final String? period = match.group(3)?.toLowerCase();
      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    return date;
  }
}

class ExecutionResult {
  final bool success;
  final String message;
  final Map<String, dynamic> data;
  ExecutionResult._({required this.success, required this.message, required this.data});
  factory ExecutionResult.success(String message, {Map<String, dynamic>? data}) {
    return ExecutionResult._(success: true, message: message, data: data ?? <String, dynamic>{});
  }
  factory ExecutionResult.error(String message) {
    return ExecutionResult._(success: false, message: message, data: <String, dynamic>{});
  }
}
