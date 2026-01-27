
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/models/event_model.dart';
import 'package:my_day/presentation/providers/data_providers.dart';
import 'package:my_day/presentation/providers/home_state_provider.dart';
import 'package:my_day/presentation/widgets/adaptive_section.dart';

class ScheduleSection extends ConsumerWidget {
  const ScheduleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final homeState = ref.watch(homeStateProvider);

    return eventsAsync.when(
      data: (events) {
        return AdaptiveSection(
          title: 'SCHEDULE',
          itemCount: events.length,
          isExpanded: homeState.isScheduleExpanded,
          onToggle: () {
            ref.read(homeStateProvider.notifier).state = homeState.copyWith(
              isScheduleExpanded: !homeState.isScheduleExpanded,
            );
          },
          trailing: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Text(
              events.length.toString(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          child: events.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text('No events scheduled for today.', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: homeState.isScheduleExpanded ? events.length : events.length.clamp(0, 3),
                  itemBuilder: (context, index) => _EventCard(event: events[index]),
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

class _EventCard extends StatelessWidget {
  final EventModel event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time
          Text(
            DateFormat('HH:mm').format(event.startTime),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          // Accent Bar
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          // Details
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
                      '${event.durationMinutes} min',
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
        ],
      ),
    );
  }
}
