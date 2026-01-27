import 'package:my_day/data/models/task_model.dart';
import 'package:my_day/services/ai/ai_service.dart';

class SmartPrioritizer {
  final AIService _aiService;

  SmartPrioritizer(this._aiService);

  /// Select the most important task to focus on
  TaskModel? selectFocusTask(List<TaskModel> tasks) {
    if (tasks.isEmpty) return null;

    // Filter out completed tasks
    final pending = tasks.where((t) => !t.isCompleted).toList();
    if (pending.isEmpty) return null;

    // Prioritize: high priority first, then by due date
    pending.sort((a, b) {
      // High priority tasks first
      if (a.priority == TaskPriority.high && b.priority != TaskPriority.high) {
        return -1;
      }
      if (b.priority == TaskPriority.high && a.priority != TaskPriority.high) {
        return 1;
      }

      // Then by due date (earlier first)
      if (a.dueDate != null && b.dueDate == null) return -1;
      if (b.dueDate != null && a.dueDate == null) return 1;
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }

      // Finally by creation date (older first)
      return a.createdAt.compareTo(b.createdAt);
    });

    return pending.first;
  }

  /// Rank tasks by importance (high priority + urgency)
  List<TaskModel> rankByImportance(List<TaskModel> tasks) {
    final pending = tasks.where((t) => !t.isCompleted).toList();

    pending.sort((a, b) {
      // Calculate importance score (0-100)
      final scoreA = _calculateImportanceScore(a);
      final scoreB = _calculateImportanceScore(b);

      return scoreB.compareTo(scoreA); // Descending order
    });

    return pending;
  }

  int _calculateImportanceScore(TaskModel task) {
    int score = 0;

    // Priority weight
    if (task.priority == TaskPriority.high) {
      score += 50;
    } else if (task.priority == TaskPriority.medium) {
      score += 25;
    }

    // Due date urgency
    if (task.dueDate != null) {
      final daysUntilDue = task.dueDate!.difference(DateTime.now()).inDays;
      if (daysUntilDue < 0) {
        score += 40; // Overdue
      } else if (daysUntilDue == 0) {
        score += 35; // Due today
      } else if (daysUntilDue == 1) {
        score += 25; // Due tomorrow
      } else if (daysUntilDue <= 7) {
        score += 15; // Due this week
      }
    }

    // Age factor (older tasks get slight boost)
    final age = DateTime.now().difference(task.createdAt).inDays;
    score += (age / 7).floor().clamp(0, 10);

    return score;
  }

  /// Get AI-generated insight about task priorities
  Future<String> generatePriorityInsight(List<TaskModel> tasks) async {
    final pending = tasks.where((t) => !t.isCompleted).length;
    final high = tasks.where((t) => t.priority == TaskPriority.high && !t.isCompleted).length;
    final overdue = tasks.where((t) => t.dueDate != null && t.dueDate!.isBefore(DateTime.now()) && !t.isCompleted).length;

    if (overdue > 0) {
      return '⚠️ You have $overdue overdue ${overdue == 1 ? 'task' : 'tasks'}. Focus on those first!';
    } else if (high > 0) {
      return '🎯 $high high-priority ${high == 1 ? 'task needs' : 'tasks need'} your attention.';
    } else if (pending > 0) {
      return '✨ You have $pending ${pending == 1 ? 'task' : 'tasks'} to complete. Keep going!';
    } else {
      return '🎉 All caught up! Great work!';
    }
  }
}
