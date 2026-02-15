import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/sources/app_database.dart';
import 'package:my_day/presentation/providers/timeline_provider.dart';
import 'package:my_day/presentation/providers/data_providers.dart';
import 'package:my_day/data/models/note_model.dart';

class TimelineView extends ConsumerWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TimelineItem>> timeline = ref.watch(timelineProvider);
    final notesAsync = ref.watch(notesProvider);
    
    return timeline.when(
      data: (List<TimelineItem> items) {
        // Get notes that are linked to timeline items
        final allNotes = notesAsync.value ?? [];
        final linkedNotes = allNotes.where((n) => 
          n.linkedTaskId != null || n.linkedEventId != null
        ).toList();
        
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // "Today" divider
            const _SectionDivider(label: 'Today'),
            const SizedBox(height: 12),
            
            // Timeline items
            if (items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No items yet', style: TextStyle(color: Colors.grey.shade600)),
                ),
              )
            else
              ...items.map((item) => _TimelineTile(item: item)),
            
            // Related Notes section
            if (linkedNotes.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionDivider(label: 'Related Notes'),
              const SizedBox(height: 12),
              ...linkedNotes.map((note) => _RelatedNoteCard(note: note)),
            ],
          ],
        );
      },
      error: (Object error, StackTrace stackTrace) => Center(child: Text(error.toString())),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String label;
  
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.item});
  final TimelineItem item;

  @override
  Widget build(BuildContext context) {
    final bool isEvent = item.type == 'event';
    final String title = isEvent ? (item.item as Event).title : (item.item as Task).title;
    final DateTime? time = isEvent 
      ? (item.item as Event).startTime 
      : (item.item as Task).dueDate;
    
    // Calculate duration for events
    int? durationMinutes;
    if (isEvent) {
      final event = item.item as Event;
      if (event.endTime != null) {
        durationMinutes = event.endTime!.difference(event.startTime).inMinutes;
      }
    }
    
    // Check for high priority tasks (priority is a String: 'high', 'medium', 'low')
    final bool isHighPriority = !isEvent && (item.item as Task).priority == 'high';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time label
          SizedBox(
            width: 60,
            child: time != null
              ? Text(
                  DateFormat('h:mm a').format(time),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : const SizedBox.shrink(),
          ),
          
          // Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isEvent 
                  ? AppTheme.accentBlue.withValues(alpha: 0.1) 
                  : Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEvent 
                    ? AppTheme.accentBlue.withValues(alpha: 0.2) 
                    : Colors.amber.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isEvent ? Icons.event : Icons.check_box_outline_blank,
                    color: isEvent ? AppTheme.accentBlue : Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (isHighPriority)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentRed.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '!',
                                  style: TextStyle(
                                    color: AppTheme.accentRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (durationMinutes != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${durationMinutes}m',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedNoteCard extends StatelessWidget {
  final NoteModel note;

  const _RelatedNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: Colors.purple.shade400, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (note.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note.content,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: note.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    color: Colors.purple.shade300,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
