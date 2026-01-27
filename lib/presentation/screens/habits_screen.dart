import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/models/habit_model.dart';
import 'package:my_day/presentation/providers/habits_provider.dart';
import 'package:my_day/presentation/widgets/floating_ai_button.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text('Habits'),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Habits list
                Expanded(
                  child: habitsAsync.when(
                    data: (habits) {
                      if (habits.isEmpty) {
                        return const Center(
                          child: Text(
                            'No habits tracked yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: habits.length,
                        itemBuilder: (context, index) => _HabitRow(habit: habits[index]),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            ),
          ),
          const FloatingAIButton(),
        ],
      ),
    );
  }
}

class _HabitRow extends ConsumerWidget {
  final HabitModel habit;

  const _HabitRow({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final last7Days = List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon
              if (habit.icon != null)
                Text(
                  habit.icon!,
                  style: const TextStyle(fontSize: 24),
                ),
              const SizedBox(width: 12),
              
              // Title and streak
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '${habit.streakCount} day streak',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Today's checkmark
              GestureDetector(
                onTap: () {
                  ref.read(habitsProvider.notifier).logCompletion(habit.id);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentBlue, width: 2),
                    color: Colors.transparent,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 18,
                    color: AppTheme.accentBlue,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 7-day grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: last7Days.map((day) {
              final dayStr = day.day.toString();
              final isToday = day.day == now.day;
              
              return Column(
                children: [
                  Text(
                    _getDayAbbr(day.weekday),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday ? AppTheme.accentBlue.withOpacity(0.2) : Colors.grey[200],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      dayStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? AppTheme.accentBlue : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getDayAbbr(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}
