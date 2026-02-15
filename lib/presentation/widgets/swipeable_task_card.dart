import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/models/task_model.dart';
import 'package:my_day/presentation/providers/data_providers.dart';

class SwipeableTaskCard extends ConsumerWidget {
  final TaskModel task;

  const SwipeableTaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(task.id),
      background: _buildSwipeBackground(
        color: Colors.green,
        icon: Icons.check_circle,
        alignment: Alignment.centerLeft,
        text: 'Complete',
      ),
      secondaryBackground: _buildSwipeBackground(
        color: Colors.blue,
        icon: Icons.schedule,
        alignment: Alignment.centerRight,
        text: 'Reschedule',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right → Complete
          await ref.read(tasksProvider.notifier).toggleTaskCompletion(task);
          return false; // Don't remove from list, just mark complete
        } else {
          // Swipe left → Reschedule (show date picker)
          final newDate = await showDatePicker(
            context: context,
            initialDate: task.dueDate ?? DateTime.now().add(const Duration(days: 1)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          
          if (newDate != null) {
            final updatedTask = task.copyWith(dueDate: newDate);
            await ref.read(tasksProvider.notifier).updateTask(updatedTask);
          }
          return false; // Don't remove from list
        }
      },
      child: _buildTaskCard(context, ref),
    );
  }

  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required Alignment alignment,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ] else ...[
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 28),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Custom Checkbox
          GestureDetector(
            onTap: () {
              ref.read(tasksProvider.notifier).toggleTaskCompletion(task);
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.isCompleted ? AppTheme.accentBlue : Colors.grey,
                  width: 2,
                ),
                color: task.isCompleted ? AppTheme.accentBlue : Colors.transparent,
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted ? Colors.grey : AppTheme.primaryText,
                  ),
                ),
                if (task.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDueDate(task.dueDate!),
                    style: TextStyle(
                      fontSize: 12,
                      color: _isOverdue(task.dueDate!) ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (task.priority == TaskPriority.high)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.accentRed,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            Icons.drag_indicator,
            color: Colors.grey[400],
            size: 20,
          ),
        ],
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate == today) {
      return 'Due today';
    } else if (taskDate == tomorrow) {
      return 'Due tomorrow';
    } else if (taskDate.isBefore(today)) {
      final diff = today.difference(taskDate).inDays;
      return 'Overdue by $diff ${diff == 1 ? 'day' : 'days'}';
    } else {
      final diff = taskDate.difference(today).inDays;
      return 'Due in $diff ${diff == 1 ? 'day' : 'days'}';
    }
  }

  bool _isOverdue(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    return taskDate.isBefore(today);
  }
}
