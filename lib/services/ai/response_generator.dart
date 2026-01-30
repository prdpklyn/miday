import 'dart:math';

/// Generates natural language responses for assistant actions.
/// Uses template-based responses for reliability and speed.
class ResponseGenerator {
  final Random _random = Random();

  /// Generate a natural confirmation for a created task
  String taskCreated({
    required String title,
    String? priority,
    DateTime? dueDate,
  }) {
    final templates = [
      "✓ Added '$title' to your tasks!",
      "Got it! '$title' is now on your list.",
      "Done! I've added '$title' to your tasks.",
      "📝 '$title' has been added.",
    ];

    String response = _pickRandom(templates);

    // Add priority context
    if (priority == 'high') {
      response += " Marked as high priority.";
    }

    // Add due date context
    if (dueDate != null) {
      final dateStr = _formatRelativeDate(dueDate);
      response += " Due $dateStr.";
    }

    return response;
  }

  /// Generate a natural confirmation for a created event
  String eventCreated({
    required String title,
    required DateTime startTime,
    int? durationMinutes,
  }) {
    final timeStr = _formatTime(startTime);
    final dateStr = _formatRelativeDate(startTime);

    final templates = [
      "📅 Scheduled '$title' for $dateStr at $timeStr.",
      "Got it! '$title' is set for $dateStr at $timeStr.",
      "Done! I've added '$title' to your schedule at $timeStr.",
      "✓ '$title' has been scheduled for $timeStr.",
    ];

    String response = _pickRandom(templates);

    if (durationMinutes != null && durationMinutes > 0) {
      response += " Blocked ${durationMinutes} minutes for it.";
    }

    return response;
  }

  /// Generate a natural confirmation for a created note
  String noteCreated({
    required String title,
    List<String>? tags,
  }) {
    final templates = [
      "📝 Note '$title' saved!",
      "Got it! I've captured that in '$title'.",
      "Done! Note saved as '$title'.",
      "✓ '$title' is now in your notes.",
    ];

    String response = _pickRandom(templates);

    if (tags != null && tags.isNotEmpty) {
      response += " Tagged with: ${tags.join(', ')}.";
    }

    return response;
  }

  /// Generate summary of tasks
  String tasksSummary({
    required int total,
    required int completed,
    required int highPriority,
    List<String>? topTasks,
  }) {
    if (total == 0) {
      return "You have no tasks right now. Want me to add one?";
    }

    final pending = total - completed;
    String response = "You have $pending pending task${pending == 1 ? '' : 's'}";

    if (highPriority > 0) {
      response += " ($highPriority high priority)";
    }

    response += ".";

    if (topTasks != null && topTasks.isNotEmpty) {
      final preview = topTasks.take(2).join(', ');
      response += " Top items: $preview.";
    }

    return response;
  }

  /// Generate summary of today's schedule
  String scheduleSummary({
    required int eventCount,
    required int taskCount,
    String? nextEvent,
    String? nextEventTime,
  }) {
    if (eventCount == 0 && taskCount == 0) {
      return "Your day is wide open! No events or tasks scheduled.";
    }

    final parts = <String>[];

    if (eventCount > 0) {
      parts.add("$eventCount event${eventCount == 1 ? '' : 's'}");
    }
    if (taskCount > 0) {
      parts.add("$taskCount task${taskCount == 1 ? '' : 's'}");
    }

    String response = "Today you have ${parts.join(' and ')}.";

    if (nextEvent != null && nextEventTime != null) {
      response += " Next up: $nextEvent at $nextEventTime.";
    }

    return response;
  }

  /// Generate response for general chat / gratitude
  String conversationalResponse(String intent) {
    switch (intent.toLowerCase()) {
      case 'thanks':
      case 'thank you':
      case 'ty':
        return _pickRandom([
          "You're welcome! Anything else I can help with?",
          "Happy to help! 😊",
          "Anytime! Let me know if you need anything else.",
          "No problem! I'm here when you need me.",
        ]);

      case 'hi':
      case 'hello':
      case 'hey':
        return _pickRandom([
          "Hey! How can I help you today?",
          "Hi there! What would you like to do?",
          "Hello! Ready to help you organize your day.",
          "Hey! What's on your mind?",
        ]);

      case 'help':
        return "I can help you with:\n"
            "• Add tasks: \"Add buy groceries\"\n"
            "• Schedule events: \"Meeting at 3pm tomorrow\"\n"
            "• Take notes: \"Note about project ideas\"\n"
            "• Check schedule: \"What's on today?\"\n"
            "\nJust tell me what you need!";

      default:
        return _pickRandom([
          "I'm not sure I understood that. Try asking me to add a task, schedule an event, or check your day.",
          "Hmm, I didn't catch that. Would you like me to add something to your tasks or schedule?",
          "I'm here to help organize your day! Try \"Add a task\" or \"What's my schedule?\"",
        ]);
    }
  }

  /// Generate error/fallback response
  String errorResponse([String? context]) {
    final templates = [
      "Sorry, I had trouble with that. Could you try rephrasing?",
      "I couldn't process that request. Try something like 'Add a task to call mom'.",
      "Hmm, something went wrong. Let's try again - what would you like to do?",
    ];
    return _pickRandom(templates);
  }

  // ========== Helper Methods ==========

  String _pickRandom(List<String> options) {
    return options[_random.nextInt(options.length)];
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    if (minute == 0) {
      return '$displayHour $period';
    }
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);
    final difference = targetDay.difference(today).inDays;

    if (difference == 0) return 'today';
    if (difference == 1) return 'tomorrow';
    if (difference == -1) return 'yesterday';
    if (difference > 1 && difference <= 7) {
      return _weekdayName(date.weekday);
    }

    return '${date.month}/${date.day}';
  }

  String _weekdayName(int weekday) {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday];
  }
}
