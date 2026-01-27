import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/data/models/task_model.dart';
import 'package:my_day/data/models/event_model.dart';
import 'package:my_day/data/models/note_model.dart';
import 'package:my_day/data/sources/database_helper.dart';

// Database Provider
final databaseHelperProvider = Provider((ref) => DatabaseHelper.instance);

// Tasks Provider
final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<TaskModel>>(() {
  return TasksNotifier();
});

class TasksNotifier extends AsyncNotifier<List<TaskModel>> {
  late DatabaseHelper _db;

  @override
  Future<List<TaskModel>> build() async {
    _db = ref.read(databaseHelperProvider);
    return await _db.getAllTasks();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _db.getAllTasks());
  }

  Future<void> toggleTaskCompletion(TaskModel task) async {
    final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
    await _db.updateTask(updatedTask);
    await refresh();
  }

  Future<void> updateTask(TaskModel task) async {
    await _db.updateTask(task);
    await refresh();
  }
}

// Events Provider
final eventsProvider = AsyncNotifierProvider<EventsNotifier, List<EventModel>>(() {
  return EventsNotifier();
});

class EventsNotifier extends AsyncNotifier<List<EventModel>> {
  late DatabaseHelper _db;

  @override
  Future<List<EventModel>> build() async {
    _db = ref.read(databaseHelperProvider);
    return await _db.getAllEvents();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _db.getAllEvents());
  }
}

// Notes Provider
final notesProvider = AsyncNotifierProvider<NotesNotifier, List<NoteModel>>(() {
  return NotesNotifier();
});

class NotesNotifier extends AsyncNotifier<List<NoteModel>> {
  late DatabaseHelper _db;

  @override
  Future<List<NoteModel>> build() async {
    _db = ref.read(databaseHelperProvider);
    return await _db.getAllNotes();
  }
  
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _db.getAllNotes());
  }
}
