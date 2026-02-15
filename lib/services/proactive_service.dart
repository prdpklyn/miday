enum SuggestionType { eventReminder, overdueTask, morningBriefing }

class ProactiveEvent {
  final String id;
  final String title;
  final DateTime startTime;
  ProactiveEvent({required this.id, required this.title, required this.startTime});
}

class ProactiveTask {
  final String id;
  final String title;
  final DateTime? dueDate;
  ProactiveTask({required this.id, required this.title, this.dueDate});
}

class ProactiveSuggestion {
  final SuggestionType type;
  final String message;
  final int priority;
  ProactiveSuggestion({required this.type, required this.message, required this.priority});
}

class ProactiveService {
  List<ProactiveSuggestion> generateSuggestions({
    required DateTime now,
    required List<ProactiveEvent> events,
    required List<ProactiveTask> tasks,
    required bool shownBriefingToday,
  }) {
    final List<ProactiveSuggestion> suggestions = <ProactiveSuggestion>[];
    for (final ProactiveEvent event in events) {
      final int minutes = event.startTime.difference(now).inMinutes;
      if (minutes >= 25 && minutes <= 35) {
        suggestions.add(ProactiveSuggestion(
          type: SuggestionType.eventReminder,
          message: 'Upcoming event: ${event.title}',
          priority: 3,
        ));
      }
    }
    for (final ProactiveTask task in tasks) {
      if (task.dueDate != null && task.dueDate!.isBefore(now)) {
        suggestions.add(ProactiveSuggestion(
          type: SuggestionType.overdueTask,
          message: 'Overdue task: ${task.title}',
          priority: 2,
        ));
      }
    }
    if (now.hour >= 7 && now.hour <= 9 && !shownBriefingToday) {
      suggestions.add(ProactiveSuggestion(
        type: SuggestionType.morningBriefing,
        message: 'Morning briefing is ready',
        priority: 1,
      ));
    }
    suggestions.sort((ProactiveSuggestion a, ProactiveSuggestion b) => b.priority.compareTo(a.priority));
    return suggestions;
  }
}
