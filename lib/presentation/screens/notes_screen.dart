import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/models/note_model.dart';
import 'package:my_day/presentation/providers/data_providers.dart';
import 'package:my_day/presentation/widgets/floating_ai_button.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);

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
                      const Text('Notes'),
                    ],
                  ),
                ),

                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Notes grid
                Expanded(
                  child: notesAsync.when(
                    data: (notes) {
                      if (notes.isEmpty) {
                        return const Center(
                          child: Text(
                            'No notes yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      final filteredNotes = _searchQuery.isEmpty
                          ? notes
                          : notes.where((note) =>
                              note.title.toLowerCase().contains(_searchQuery) ||
                              note.content.toLowerCase().contains(_searchQuery) ||
                              note.tags.any((tag) => tag.toLowerCase().contains(_searchQuery))).toList();

                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) => _NoteCard(note: filteredNotes[index]),
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

class _NoteCard extends StatelessWidget {
  final NoteModel note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            maxLines: 2,
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
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
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
