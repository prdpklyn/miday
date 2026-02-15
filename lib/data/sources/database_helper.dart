
import 'package:drift/drift.dart';
import 'package:my_day/data/models/event_model.dart';
import 'package:my_day/data/models/habit_model.dart';
import 'package:my_day/data/models/note_model.dart';
import 'package:my_day/data/models/task_model.dart';
import 'package:my_day/data/sources/app_database.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  final AppDatabase _database;
  DatabaseHelper._init() : _database = AppDatabase();
  Future<String> createTask(TaskModel task) async {
    await _database.insertTask(TasksCompanion.insert(
      id: task.id,
      title: task.title,
      dueDate: Value(task.dueDate),
      dueTime: Value(task.dueTime),
      priority: Value(_mapPriority(task.priority)),
      category: Value(task.category),
      completed: Value(task.isCompleted),
      linkedEventId: Value(task.linkedEventId),
    ));
    return task.id;
  }
  Future<List<TaskModel>> getAllTasks() async {
    final List<Task> tasks = await (_database.select(_database.tasks)
          ..orderBy([(Tasks t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return tasks.map(_mapTask).toList();
  }
  Future<void> updateTask(TaskModel task) async {
    final TasksCompanion update = TasksCompanion(
      title: Value(task.title),
      dueDate: Value(task.dueDate),
      dueTime: Value(task.dueTime),
      priority: Value(_mapPriority(task.priority)),
      category: Value(task.category),
      completed: Value(task.isCompleted),
      linkedEventId: Value(task.linkedEventId),
      updatedAt: Value(DateTime.now()),
    );
    await (_database.update(_database.tasks)..where((Tasks t) => t.id.equals(task.id))).write(update);
  }
  Future<void> deleteTask(String id) async {
    await (_database.delete(_database.tasks)..where((Tasks t) => t.id.equals(id))).go();
  }
  Future<String> createEvent(EventModel event) async {
    await _database.insertEvent(EventsCompanion.insert(
      id: event.id,
      title: event.title,
      date: event.date,
      startTime: event.startTime,
      endTime: Value(event.endTime),
      location: Value(event.location),
      attendees: Value(event.attendees?.join(',')),
      color: Value(event.color ?? 'blue'),
    ));
    return event.id;
  }
  Future<List<EventModel>> getAllEvents() async {
    final List<Event> events = await (_database.select(_database.events)
          ..orderBy([(Events e) => OrderingTerm.asc(e.startTime)]))
        .get();
    return events.map(_mapEvent).toList();
  }
  Future<void> deleteEvent(String id) async {
    await (_database.delete(_database.events)..where((Events e) => e.id.equals(id))).go();
  }
  Future<String> createNote(NoteModel note) async {
    await _database.insertNote(NotesCompanion.insert(
      id: note.id,
      title: Value(note.title),
      content: note.content,
      tags: Value(note.tags.join(',')),
      linkedEventId: Value(note.linkedEventId),
      linkedTaskId: Value(note.linkedTaskId),
    ));
    return note.id;
  }
  Future<List<NoteModel>> getAllNotes() async {
    final List<Note> notes = await (_database.select(_database.notes)
          ..orderBy([(Notes n) => OrderingTerm.desc(n.createdAt)]))
        .get();
    return notes.map(_mapNote).toList();
  }
  Future<void> deleteNote(String id) async {
    await (_database.delete(_database.notes)..where((Notes n) => n.id.equals(id))).go();
  }
  Future<String> createHabit(HabitModel habit) async {
    await _database.into(_database.habits).insert(HabitsCompanion.insert(
      id: habit.id,
      title: habit.title,
      icon: Value(habit.icon),
      frequency: habit.frequency.index,
      streakCount: habit.streakCount,
      createdAt: habit.createdAt,
    ));
    return habit.id;
  }
  Future<List<HabitModel>> getAllHabits() async {
    final List<Habit> habits = await (_database.select(_database.habits)
          ..orderBy([(Habits h) => OrderingTerm.asc(h.createdAt)]))
        .get();
    return habits.map(_mapHabit).toList();
  }
  Future<void> updateHabit(HabitModel habit) async {
    final HabitsCompanion update = HabitsCompanion(
      title: Value(habit.title),
      icon: Value(habit.icon),
      frequency: Value(habit.frequency.index),
      streakCount: Value(habit.streakCount),
      createdAt: Value(habit.createdAt),
    );
    await (_database.update(_database.habits)..where((Habits h) => h.id.equals(habit.id))).write(update);
  }
  Future<void> deleteHabit(String id) async {
    await (_database.delete(_database.habits)..where((Habits h) => h.id.equals(id))).go();
  }
  Future<void> logHabitCompletion(HabitLog log) async {
    await _database.into(_database.habitLogs).insert(HabitLogsCompanion.insert(
      id: log.id,
      habitId: log.habitId,
      completedAt: log.completedAt,
    ));
    final HabitModel? habit = await getHabitById(log.habitId);
    if (habit != null) {
      final int newStreak = await calculateStreak(log.habitId);
      await updateHabit(habit.copyWith(streakCount: newStreak));
    }
  }
  Future<HabitModel?> getHabitById(String id) async {
    final Habit? habit = await (_database.select(_database.habits)..where((Habits h) => h.id.equals(id))).getSingleOrNull();
    return habit == null ? null : _mapHabit(habit);
  }
  Future<List<HabitLog>> getHabitLogs(String habitId) async {
    final List<HabitLogEntry> logs = await (_database.select(_database.habitLogs)
          ..where((HabitLogs h) => h.habitId.equals(habitId))
          ..orderBy([(HabitLogs h) => OrderingTerm.desc(h.completedAt)]))
        .get();
    return logs.map((HabitLogEntry log) {
      return HabitLog(id: log.id, habitId: log.habitId, completedAt: log.completedAt);
    }).toList();
  }
  Future<int> calculateStreak(String habitId) async {
    final List<HabitLog> logs = await getHabitLogs(habitId);
    if (logs.isEmpty) return 0;
    int streak = 0;
    DateTime lastDate = DateTime.now();
    for (final HabitLog log in logs) {
      final DateTime logDate = DateTime(log.completedAt.year, log.completedAt.month, log.completedAt.day);
      final DateTime checkDate = DateTime(lastDate.year, lastDate.month, lastDate.day);
      if (logDate == checkDate || logDate == checkDate.subtract(const Duration(days: 1))) {
        streak++;
        lastDate = logDate;
      } else {
        break;
      }
    }
    return streak;
  }
  Future<List<DateTime>> getHabitCompletionDates(String habitId, {int days = 7}) async {
    final DateTime cutoffDate = DateTime.now().subtract(Duration(days: days));
    final List<HabitLogEntry> logs = await (_database.select(_database.habitLogs)
          ..where((HabitLogs h) => h.habitId.equals(habitId))
          ..where((HabitLogs h) => h.completedAt.isBiggerThanValue(cutoffDate)))
        .get();
    return logs.map((HabitLogEntry log) => log.completedAt).toList();
  }
  String _mapPriority(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 'high';
      case TaskPriority.low:
        return 'low';
      case TaskPriority.medium:
        return 'medium';
    }
  }
  TaskPriority _mapPriorityFromString(String priority) {
    switch (priority) {
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      default:
        return TaskPriority.medium;
    }
  }
  TaskModel _mapTask(Task task) {
    return TaskModel(
      id: task.id,
      title: task.title,
      description: null,
      priority: _mapPriorityFromString(task.priority),
      isCompleted: task.completed,
      createdAt: task.createdAt,
      dueDate: task.dueDate,
      dueTime: task.dueTime,
      category: task.category,
      linkedEventId: task.linkedEventId,
    );
  }
  EventModel _mapEvent(Event event) {
    final int? durationMinutes = event.endTime == null ? null : event.endTime!.difference(event.startTime).inMinutes;
    return EventModel(
      id: event.id,
      title: event.title,
      description: null,
      date: event.date,
      startTime: event.startTime,
      endTime: event.endTime,
      durationMinutes: durationMinutes,
      location: event.location,
      attendees: event.attendees?.split(',').where((String e) => e.isNotEmpty).toList(),
      color: event.color,
    );
  }
  NoteModel _mapNote(Note note) {
    return NoteModel(
      id: note.id,
      title: note.title ?? '',
      content: note.content,
      tags: note.tags?.split(',').where((String e) => e.isNotEmpty).toList() ?? <String>[],
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      backgroundColor: null,
      linkedEventId: note.linkedEventId,
      linkedTaskId: note.linkedTaskId,
    );
  }
  HabitModel _mapHabit(Habit habit) {
    return HabitModel(
      id: habit.id,
      title: habit.title,
      icon: habit.icon,
      frequency: HabitFrequency.values[habit.frequency],
      streakCount: habit.streakCount,
      createdAt: habit.createdAt,
    );
  }
}
