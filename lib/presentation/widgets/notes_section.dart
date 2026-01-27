
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/models/note_model.dart';
import 'package:my_day/presentation/providers/data_providers.dart';
import 'package:my_day/presentation/providers/home_state_provider.dart';
import 'package:my_day/presentation/widgets/adaptive_section.dart';

class NotesSection extends ConsumerWidget {
  const NotesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final homeState = ref.watch(homeStateProvider);

    return notesAsync.when(
      data: (notes) {
        return AdaptiveSection(
          title: 'NOTES',
          itemCount: notes.length,
          isExpanded: homeState.isNotesExpanded,
          onToggle: () {
            ref.read(homeStateProvider.notifier).state = homeState.copyWith(
              isNotesExpanded: !homeState.isNotesExpanded,
            );
          },
          child: notes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text('No notes yet.', style: TextStyle(color: Colors.grey)),
                )
              : SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: notes.length,
                    itemBuilder: (context, index) => _NoteCard(note: notes[index]),
                  ),
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

class _NoteCard extends StatelessWidget {
  final NoteModel note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.noteYellow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.yellow[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              note.content,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.primaryText,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: note.tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.noteTagYellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$tag',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
