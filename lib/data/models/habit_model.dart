
enum HabitFrequency { daily, weekly, custom }

class HabitModel {
  final String id;
  final String title;
  final String? icon;
  final HabitFrequency frequency;
  final int streakCount;
  final DateTime createdAt;

  HabitModel({
    required this.id,
    required this.title,
    this.icon,
    this.frequency = HabitFrequency.daily,
    this.streakCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'frequency': frequency.index,
      'streakCount': streakCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HabitModel.fromMap(Map<String, dynamic> map) {
    return HabitModel(
      id: map['id'],
      title: map['title'],
      icon: map['icon'],
      frequency: HabitFrequency.values[map['frequency'] ?? 0],
      streakCount: map['streakCount'] ?? 0,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  HabitModel copyWith({
    String? title,
    String? icon,
    HabitFrequency? frequency,
    int? streakCount,
  }) {
    return HabitModel(
      id: id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      frequency: frequency ?? this.frequency,
      streakCount: streakCount ?? this.streakCount,
      createdAt: createdAt,
    );
  }
}

class HabitLog {
  final String id;
  final String habitId;
  final DateTime completedAt;

  HabitLog({
    required this.id,
    required this.habitId,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory HabitLog.fromMap(Map<String, dynamic> map) {
    return HabitLog(
      id: map['id'],
      habitId: map['habitId'],
      completedAt: DateTime.parse(map['completedAt']),
    );
  }
}
