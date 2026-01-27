
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:my_day/data/models/task_model.dart';
import 'package:my_day/data/models/event_model.dart';
import 'package:my_day/data/models/note_model.dart';
import 'package:my_day/data/models/habit_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cadence.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // Tasks Table
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        priority INTEGER NOT NULL,
        isCompleted INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        dueDate TEXT
      )
    ''');

    // Events Table
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        startTime TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        color TEXT
      )
    ''');

    // Notes Table
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        tags TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        backgroundColor TEXT
      )
    ''');

    // Habits Table
    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        icon TEXT,
        frequency INTEGER NOT NULL,
        streakCount INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Habit Logs Table
    await db.execute('''
      CREATE TABLE habit_logs (
        id TEXT PRIMARY KEY,
        habitId TEXT NOT NULL,
        completedAt TEXT NOT NULL,
        FOREIGN KEY (habitId) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- CRUD Operations ---

  // Tasks
  Future<String> createTask(TaskModel task) async {
    final db = await instance.database;
    await db.insert('tasks', task.toMap());
    return task.id;
  }

  Future<List<TaskModel>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks', orderBy: 'createdAt DESC');
    return result.map((json) => TaskModel.fromMap(json)).toList();
  }
  
  Future<void> updateTask(TaskModel task) async {
    final db = await instance.database;
    await db.update(
      'tasks', 
      task.toMap(), 
      where: 'id = ?', 
      whereArgs: [task.id]
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await instance.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // Events
  Future<String> createEvent(EventModel event) async {
    final db = await instance.database;
    await db.insert('events', event.toMap());
    return event.id;
  }

  Future<List<EventModel>> getAllEvents() async {
    final db = await instance.database;
    final result = await db.query('events', orderBy: 'startTime ASC');
    return result.map((json) => EventModel.fromMap(json)).toList();
  }

  Future<void> deleteEvent(String id) async {
    final db = await instance.database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  // Notes
  Future<String> createNote(NoteModel note) async {
    final db = await instance.database;
    await db.insert('notes', note.toMap());
    return note.id;
  }

  Future<List<NoteModel>> getAllNotes() async {
    final db = await instance.database;
    final result = await db.query('notes', orderBy: 'createdAt DESC');
    return result.map((json) => NoteModel.fromMap(json)).toList();
  }

  Future<void> deleteNote(String id) async {
    final db = await instance.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // Habits
  Future<String> createHabit(HabitModel habit) async {
    final db = await instance.database;
    await db.insert('habits', habit.toMap());
    return habit.id;
  }

  Future<List<HabitModel>> getAllHabits() async {
    final db = await instance.database;
    final result = await db.query('habits', orderBy: 'createdAt ASC');
    return result.map((json) => HabitModel.fromMap(json)).toList();
  }

  Future<void> updateHabit(HabitModel habit) async {
    final db = await instance.database;
    await db.update(
      'habits',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<void> deleteHabit(String id) async {
    final db = await instance.database;
    await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // Habit Logs
  Future<void> logHabitCompletion(HabitLog log) async {
    final db = await instance.database;
    await db.insert('habit_logs', log.toMap());
    
    // Update streak count
    final habit = await getHabitById(log.habitId);
    if (habit != null) {
      final newStreak = await calculateStreak(log.habitId);
      await updateHabit(habit.copyWith(streakCount: newStreak));
    }
  }

  Future<HabitModel?> getHabitById(String id) async {
    final db = await instance.database;
    final result = await db.query('habits', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return HabitModel.fromMap(result.first);
  }

  Future<List<HabitLog>> getHabitLogs(String habitId) async {
    final db = await instance.database;
    final result = await db.query(
      'habit_logs',
      where: 'habitId = ?',
      whereArgs: [habitId],
      orderBy: 'completedAt DESC',
    );
    return result.map((json) => HabitLog.fromMap(json)).toList();
  }

  Future<int> calculateStreak(String habitId) async {
    final logs = await getHabitLogs(habitId);
    if (logs.isEmpty) return 0;

    int streak = 0;
    DateTime lastDate = DateTime.now();
    
    for (var log in logs) {
      final logDate = DateTime(log.completedAt.year, log.completedAt.month, log.completedAt.day);
      final checkDate = DateTime(lastDate.year, lastDate.month, lastDate.day);
      
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
    final db = await instance.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    
    final result = await db.query(
      'habit_logs',
      where: 'habitId = ? AND completedAt >= ?',
      whereArgs: [habitId, cutoffDate.toIso8601String()],
    );
    
    return result.map((log) => DateTime.parse(log['completedAt'] as String)).toList();
  }
}
