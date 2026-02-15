
class EventModel {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final String? location;
  final List<String>? attendees;
  final String? color; // Hex string

  EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    this.location,
    this.attendees,
    this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'location': location,
      'attendees': attendees?.join(','),
      'color': color,
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      date: DateTime.parse(map['date'] ?? map['startTime']),
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      durationMinutes: map['durationMinutes'],
      location: map['location'],
      attendees: (map['attendees'] as String?)?.split(',').where((String e) => e.isNotEmpty).toList(),
      color: map['color'],
    );
  }
}
