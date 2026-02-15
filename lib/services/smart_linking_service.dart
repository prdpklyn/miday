class LinkableEvent {
  final String id;
  final String title;
  final DateTime startTime;
  LinkableEvent({required this.id, required this.title, required this.startTime});
}

class LinkableTask {
  final String id;
  final String title;
  final DateTime? dueTime;
  LinkableTask({required this.id, required this.title, this.dueTime});
}

class LinkableNote {
  final String id;
  final String? title;
  final String content;
  LinkableNote({required this.id, this.title, required this.content});
}

class LinkSuggestion {
  final String sourceId;
  final String targetId;
  final String type;
  final double score;
  LinkSuggestion({
    required this.sourceId,
    required this.targetId,
    required this.type,
    required this.score,
  });
}

class SmartLinkingService {
  List<LinkSuggestion> suggestLinks({
    required List<LinkableEvent> events,
    required List<LinkableTask> tasks,
    required List<LinkableNote> notes,
  }) {
    final List<LinkSuggestion> suggestions = <LinkSuggestion>[];
    for (final LinkableTask task in tasks) {
      for (final LinkableEvent event in events) {
        if (task.dueTime == null) continue;
        final Duration diff = task.dueTime!.difference(event.startTime).abs();
        if (diff.inMinutes <= 60) {
          suggestions.add(LinkSuggestion(
            sourceId: task.id,
            targetId: event.id,
            type: 'task_event',
            score: 0.8,
          ));
        }
      }
    }
    for (final LinkableNote note in notes) {
      final String noteText = '${note.title ?? ''} ${note.content}'.toLowerCase();
      for (final LinkableEvent event in events) {
        final String title = event.title.toLowerCase();
        if (noteText.contains(title)) {
          suggestions.add(LinkSuggestion(
            sourceId: note.id,
            targetId: event.id,
            type: 'note_event',
            score: 0.7,
          ));
        }
      }
      for (final LinkableTask task in tasks) {
        final String title = task.title.toLowerCase();
        if (noteText.contains(title)) {
          suggestions.add(LinkSuggestion(
            sourceId: note.id,
            targetId: task.id,
            type: 'note_task',
            score: 0.7,
          ));
        }
      }
    }
    return suggestions;
  }
}
