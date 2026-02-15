import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/models/task_model.dart';
import 'package:my_day/presentation/providers/data_providers.dart';

class TasksSection extends ConsumerWidget {
  const TasksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final notesAsync = ref.watch(notesProvider);

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No tasks yet',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        }
        
        // Get linked notes for tasks
        final linkedNotes = notesAsync.value ?? [];
        
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: tasks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final task = tasks[index];
            final hasLinkedNote = linkedNotes.any((n) => n.linkedTaskId == task.id);
            return _TaskCard(task: task, hasLinkedNote: hasLinkedNote);
          },
        );
      },
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool hasLinkedNote;

  const _TaskCard({required this.task, required this.hasLinkedNote});

  @override
  Widget build(BuildContext context) {
    final dueDateText = _getDueDateText(task.dueDate);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox circle
          GestureDetector(
            onTap: () {
              // TODO: Toggle task completion
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.isCompleted ? Colors.green : Colors.grey.shade400,
                  width: 2,
                ),
                color: task.isCompleted ? Colors.green : Colors.transparent,
              ),
              child: task.isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
            ),
          ),
          const SizedBox(width: 12),
          
          // Task details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted ? Colors.grey : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (dueDateText != null) ...[
                      Text(
                        dueDateText,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (hasLinkedNote) ...[
                      if (dueDateText != null) const SizedBox(width: 12),
                      Icon(Icons.note, size: 14, color: Colors.purple.shade300),
                      const SizedBox(width: 4),
                      Text(
                        'Note attached',
                        style: TextStyle(
                          color: Colors.purple.shade300,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Priority badge
          if (task.priority == TaskPriority.high)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'High',
                style: TextStyle(
                  color: AppTheme.accentRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _getDueDateText(DateTime? dueDate) {
    if (dueDate == null) return null;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    
    final difference = due.difference(today).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference < 0) return 'Overdue';
    if (difference <= 7) return 'This week';
    return 'This month';
  }
}
