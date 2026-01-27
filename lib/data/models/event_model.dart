
class EventModel {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final int durationMinutes;
  final String? color; // Hex string

  EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.durationMinutes,
    this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'color': color,
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      startTime: DateTime.parse(map['startTime']),
      durationMinutes: map['durationMinutes'],
      color: map['color'],
    );
  }
}
