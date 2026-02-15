import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Events extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get attendees => text().nullable()();
  TextColumn get color => text().withDefault(const Constant('blue'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get dueTime => dateTime().nullable()();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  TextColumn get category => text().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  TextColumn get linkedEventId => text().nullable().references(Events, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text()();
  TextColumn get tags => text().nullable()();
  TextColumn get linkedEventId => text().nullable().references(Events, #id)();
  TextColumn get linkedTaskId => text().nullable().references(Tasks, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get icon => text().nullable()();
  IntColumn get frequency => integer()();
  IntColumn get streakCount => integer()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HabitLogEntry')
class HabitLogs extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();
  DateTimeColumn get completedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Events, Tasks, Notes, Habits, HabitLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);
  @override
  int get schemaVersion => 1;
  Future<List<Event>> getEventsForDate(DateTime date) {
    final DateTime startOfDay = DateTime(date.year, date.month, date.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(events)
          ..where((Events e) => e.date.isBetweenValues(startOfDay, endOfDay))
          ..orderBy([(Events e) => OrderingTerm.asc(e.startTime)]))
        .get();
  }
  Future<List<Task>> getTasksForDate(DateTime date) {
    final DateTime startOfDay = DateTime(date.year, date.month, date.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(tasks)
          ..where((Tasks t) => t.dueDate.isBetweenValues(startOfDay, endOfDay) | t.dueDate.isNull())
          ..where((Tasks t) => t.completed.equals(false))
          ..orderBy([
            (Tasks t) => OrderingTerm.desc(t.priority),
            (Tasks t) => OrderingTerm.asc(t.dueTime),
          ]))
        .get();
  }
  Future<int> insertEvent(EventsCompanion event) {
    return into(events).insert(event);
  }
  Future<int> insertTask(TasksCompanion task) {
    return into(tasks).insert(task);
  }
  Future<int> insertNote(NotesCompanion note) {
    return into(notes).insert(note);
  }
  Future<List<Note>> getNotesLinkedToEvent(String eventId) {
    return (select(notes)..where((Notes n) => n.linkedEventId.equals(eventId))).get();
  }
  Future<List<Note>> getNotesLinkedToTask(String taskId) {
    return (select(notes)..where((Notes n) => n.linkedTaskId.equals(taskId))).get();
  }
  Future<List<Note>> searchNotes(String query) {
    final String pattern = '%${query.toLowerCase()}%';
    final Selectable<QueryRow> selectable = customSelect(
      'SELECT * FROM notes WHERE lower(content) LIKE ? OR lower(COALESCE(title, "")) LIKE ? OR lower(COALESCE(tags, "")) LIKE ?',
      variables: [Variable<String>(pattern), Variable<String>(pattern), Variable<String>(pattern)],
      readsFrom: {notes},
    );
    return selectable.get().then((List<QueryRow> rows) {
      final Iterable<Future<Note>> mapped = rows.map((QueryRow row) => notes.mapFromRow(row));
      return Future.wait(mapped);
    });
  }
  Future<List<TimelineItem>> getTimelineForDate(DateTime date) async {
    final List<Event> dayEvents = await getEventsForDate(date);
    final List<Task> dayTasks = await getTasksForDate(date);
    final List<TimelineItem> items = <TimelineItem>[];
    for (final Event event in dayEvents) {
      final List<Note> linkedNotes = await getNotesLinkedToEvent(event.id);
      items.add(TimelineItem.event(event, linkedNotes));
    }
    for (final Task task in dayTasks) {
      final List<Note> linkedNotes = await getNotesLinkedToTask(task.id);
      items.add(TimelineItem.task(task, linkedNotes));
    }
    items.sort((TimelineItem a, TimelineItem b) => a.sortTime.compareTo(b.sortTime));
    return items;
  }
}

class TimelineItem {
  final String type;
  final Object item;
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
    final DateTime sortTime = task.dueTime ?? DateTime(2099);
    return TimelineItem._(
      type: 'task',
      item: task,
      linkedNotes: notes,
      sortTime: sortTime,
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File(path.join(directory.path, 'myday.sqlite'));
    return NativeDatabase(file);
  });
}
