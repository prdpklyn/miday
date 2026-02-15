import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/models/event_model.dart';
import 'package:my_day/presentation/providers/data_providers.dart';

class ScheduleSection extends ConsumerWidget {
  const ScheduleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No events scheduled',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        }
        
        // Sort events by start time
        final sortedEvents = List<EventModel>.from(events)
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: sortedEvents.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _EventCard(event: sortedEvents[index]),
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

class _EventCard extends StatelessWidget {
  final EventModel event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final timeString = DateFormat('h:mm a').format(event.startTime);
    
    // Get duration either from explicit field or calculate from end time
    final int duration;
    if (event.durationMinutes != null) {
      duration = event.durationMinutes!;
    } else if (event.endTime != null) {
      duration = event.endTime!.difference(event.startTime).inMinutes;
    } else {
      duration = 30; // Default duration
    }
    
    final durationString = _formatDuration(duration);
    
    // Determine if event is upcoming or past
    final now = DateTime.now();
    final isUpcoming = event.startTime.isAfter(now);
    final isOngoing = event.startTime.isBefore(now) && 
      event.startTime.add(Duration(minutes: duration)).isAfter(now);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
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
                Text(
                  '$timeString · $durationString',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Status indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOngoing 
                ? Colors.green 
                : (isUpcoming ? AppTheme.accentBlue : Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else if (minutes % 60 == 0) {
      return '${minutes ~/ 60}h';
    } else {
      return '${minutes ~/ 60}h ${minutes % 60}m';
    }
  }
}
