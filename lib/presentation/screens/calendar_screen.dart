import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/models/event_model.dart';
import 'package:my_day/presentation/providers/data_providers.dart';
import 'package:my_day/presentation/widgets/floating_ai_button.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final now = DateTime.now();

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
                      Text(
                        DateFormat('MMMM yyyy').format(now),
                        style: AppTheme.heading1,
                      ),
                    ],
                  ),
                ),

                // Week strip
                _buildWeekStrip(now),

                const SizedBox(height: 20),

                // Timeline
                Expanded(
                  child: eventsAsync.when(
                    data: (events) {
                      if (events.isEmpty) {
                        return const Center(
                          child: Text(
                            'No events scheduled',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: events.length,
                        itemBuilder: (context, index) => _EventPill(event: events[index]),
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

  Widget _buildWeekStrip(DateTime now) {
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final day = weekStart.add(Duration(days: index));
          final isToday = day.day == now.day && day.month == now.month;
          
          return Column(
            children: [
              Text(
                DateFormat('E').format(day),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isToday ? AppTheme.accentBlue : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  day.day.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : AppTheme.primaryText,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _EventPill extends StatelessWidget {
  final EventModel event;

  const _EventPill({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('HH:mm').format(event.startTime)} • ${event.durationMinutes} min',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
