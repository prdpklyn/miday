
enum TaskPriority { high, medium, low }

class TaskModel {
  final String id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? dueTime;
  final String? category;
  final String? linkedEventId;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.priority = TaskPriority.medium,
    this.isCompleted = false,
    required this.createdAt,
    this.dueDate,
    this.dueTime,
    this.category,
    this.linkedEventId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority.index,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'dueTime': dueTime?.toIso8601String(),
      'category': category,
      'linkedEventId': linkedEventId,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      priority: TaskPriority.values[map['priority'] ?? 1],
      isCompleted: map['isCompleted'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      dueTime: map['dueTime'] != null ? DateTime.parse(map['dueTime']) : null,
      category: map['category'],
      linkedEventId: map['linkedEventId'],
    );
  }

  TaskModel copyWith({
    String? title,
    String? description,
    TaskPriority? priority,
    bool? isCompleted,
    DateTime? dueDate,
    DateTime? dueTime,
    String? category,
    String? linkedEventId,
  }) {
    return TaskModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      category: category ?? this.category,
      linkedEventId: linkedEventId ?? this.linkedEventId,
    );
  }
}
