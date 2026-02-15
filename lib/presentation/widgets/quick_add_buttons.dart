import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/data/models/event_model.dart';
import 'package:my_day/data/models/task_model.dart';
import 'package:my_day/data/models/note_model.dart';
import 'package:my_day/presentation/providers/data_providers.dart';

/// Quick add buttons for creating events, tasks, and notes
class QuickAddButtons extends ConsumerWidget {
  const QuickAddButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickAddButton(
            label: '+ Event',
            color: AppTheme.accentBlue,
            isFilled: false,
            onTap: () => _showAddEventDialog(context, ref),
          ),
          _QuickAddButton(
            label: '+ Task',
            color: Colors.amber.shade700,
            isFilled: true,
            onTap: () => _showAddTaskDialog(context, ref),
          ),
          _QuickAddButton(
            label: '+ Note',
            color: Colors.purple,
            isFilled: false,
            onTap: () => _showAddNoteDialog(context, ref),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    TaskPriority selectedPriority = TaskPriority.medium;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Task',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Priority: '),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Low'),
                    selected: selectedPriority == TaskPriority.low,
                    onSelected: (_) => setState(() => selectedPriority = TaskPriority.low),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Medium'),
                    selected: selectedPriority == TaskPriority.medium,
                    onSelected: (_) => setState(() => selectedPriority = TaskPriority.medium),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('High'),
                    selected: selectedPriority == TaskPriority.high,
                    onSelected: (_) => setState(() => selectedPriority = TaskPriority.high),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    
                    final task = TaskModel(
                      id: const Uuid().v4(),
                      title: title,
                      priority: selectedPriority,
                      createdAt: DateTime.now(),
                      dueDate: DateTime.now(),
                    );
                    
                    final db = ref.read(databaseHelperProvider);
                    await db.createTask(task);
                    await ref.read(tasksProvider.notifier).refresh();
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Task "$title" created!')),
                      );
                    }
                  },
                  child: const Text('Add Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    int durationMinutes = 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Event',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Event title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Time: '),
                  TextButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) {
                        setState(() => selectedTime = time);
                      }
                    },
                    child: Text(
                      selectedTime.format(context),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Text('Duration: '),
                  DropdownButton<int>(
                    value: durationMinutes,
                    items: [15, 30, 45, 60, 90, 120].map((d) => 
                      DropdownMenuItem(value: d, child: Text('${d}m'))
                    ).toList(),
                    onChanged: (v) => setState(() => durationMinutes = v!),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    
                    final now = DateTime.now();
                    final startTime = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
                    final endTime = startTime.add(Duration(minutes: durationMinutes));
                    
                    final event = EventModel(
                      id: const Uuid().v4(),
                      title: title,
                      date: now,
                      startTime: startTime,
                      endTime: endTime,
                      durationMinutes: durationMinutes,
                    );
                    
                    final db = ref.read(databaseHelperProvider);
                    await db.createEvent(event);
                    await ref.read(eventsProvider.notifier).refresh();
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Event "$title" scheduled!')),
                      );
                    }
                  },
                  child: const Text('Add Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Note',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Note title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write your note...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final title = titleController.text.trim();
                  final content = contentController.text.trim();
                  if (title.isEmpty) return;
                  
                  final note = NoteModel(
                    id: const Uuid().v4(),
                    title: title,
                    content: content,
                    tags: [],
                    createdAt: DateTime.now(),
                  );
                  
                  final db = ref.read(databaseHelperProvider);
                  await db.createNote(note);
                  await ref.read(notesProvider.notifier).refresh();
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Note "$title" saved!')),
                    );
                  }
                },
                child: const Text('Save Note'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isFilled;
  final VoidCallback onTap;

  const _QuickAddButton({
    required this.label,
    required this.color,
    required this.isFilled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isFilled ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
