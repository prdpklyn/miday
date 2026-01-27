
class NoteModel {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime createdAt;
  final String? backgroundColor;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.createdAt,
    this.backgroundColor,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags.join(','), // Simple CSV for storage
      'createdAt': createdAt.toIso8601String(),
      'backgroundColor': backgroundColor,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      tags: (map['tags'] as String?)?.split(',').where((e) => e.isNotEmpty).toList() ?? [],
      createdAt: DateTime.parse(map['createdAt']),
      backgroundColor: map['backgroundColor'],
    );
  }
}
