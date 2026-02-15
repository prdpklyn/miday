import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/models/note_model.dart';
import 'package:my_day/presentation/providers/data_providers.dart';

class NotesSection extends ConsumerWidget {
  const NotesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final tasksAsync = ref.watch(tasksProvider);

    return notesAsync.when(
      data: (notes) {
        if (notes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No notes yet',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        }
        
        // Get tasks data for linked task indicator
        final tasks = tasksAsync.value ?? [];
        
        // 2-column grid layout
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            final linkedTask = note.linkedTaskId != null
              ? tasks.where((t) => t.id == note.linkedTaskId).firstOrNull
              : null;
            return _NoteCard(note: note, linkedTask: linkedTask);
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

class _NoteCard extends StatelessWidget {
  final NoteModel note;
  final dynamic linkedTask;

  const _NoteCard({required this.note, this.linkedTask});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            note.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          
          // Content preview
          Expanded(
            child: Text(
              note.content,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Tags
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: note.tags.take(3).map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              )).toList(),
            ),
          ],
          
          // Linked to task indicator
          if (linkedTask != null) ...[
            const SizedBox(height: 10),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.link, size: 14, color: Colors.purple.shade400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Linked to task',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.purple.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
