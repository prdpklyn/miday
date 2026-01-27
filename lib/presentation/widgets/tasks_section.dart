
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/models/task_model.dart';
import 'package:my_day/presentation/providers/data_providers.dart';
import 'package:my_day/presentation/providers/home_state_provider.dart';
import 'package:my_day/presentation/widgets/adaptive_section.dart';
import 'package:my_day/presentation/widgets/swipeable_task_card.dart';

class TasksSection extends ConsumerWidget {
  const TasksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final homeState = ref.watch(homeStateProvider);

    return tasksAsync.when(
      data: (tasks) {
        final highPriorityCount = tasks.where((t) => t.priority == TaskPriority.high).length;
        
        return AdaptiveSection(
          title: 'TASKS',
          itemCount: tasks.length,
          isExpanded: homeState.isTasksExpanded,
          onToggle: () {
            ref.read(homeStateProvider.notifier).state = homeState.copyWith(
              isTasksExpanded: !homeState.isTasksExpanded,
            );
          },
          trailing: highPriorityCount > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'High',
                    style: TextStyle(
                      color: AppTheme.accentRed,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          child: tasks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text('No tasks yet.', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: homeState.isTasksExpanded ? tasks.length : tasks.length.clamp(0, 3),
                  itemBuilder: (context, index) => SwipeableTaskCard(task: tasks[index]),
                ),
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
