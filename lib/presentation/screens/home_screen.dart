import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/presentation/providers/data_providers.dart';
import 'package:my_day/presentation/providers/tab_provider.dart';
import 'package:my_day/presentation/widgets/timeline_view.dart';
import 'package:my_day/presentation/widgets/schedule_section.dart';
import 'package:my_day/presentation/widgets/tasks_section.dart';
import 'package:my_day/presentation/widgets/notes_section.dart';
import 'package:my_day/presentation/widgets/voice_widget.dart';
import 'package:my_day/presentation/widgets/quick_add_buttons.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final dateString = DateFormat('EEEE, MMMM d').format(now);
    final selectedTab = ref.watch(selectedTabProvider);
    
    // Watch counts for tab badges
    final eventsAsync = ref.watch(eventsProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final notesAsync = ref.watch(notesProvider);
    
    final eventCount = eventsAsync.value?.length ?? 0;
    final taskCount = tasksAsync.value?.length ?? 0;
    final noteCount = notesAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("My Day", style: AppTheme.heading1),
                  const SizedBox(height: 4),
                  Text(dateString, style: AppTheme.bodyRegular),
                ],
              ),
            ),
            
            // Tab Bar - simplified with just icons + short labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _TabBar(
                selectedIndex: selectedTab,
                onTabSelected: (index) {
                  ref.read(selectedTabProvider.notifier).setTab(index);
                },
                eventCount: eventCount,
                taskCount: taskCount,
                noteCount: noteCount,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Voice Widget
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: VoiceWidget(),
            ),
            
            const SizedBox(height: 12),
            
            // Tab Content
            Expanded(
              child: IndexedStack(
                index: selectedTab,
                children: const [
                  TimelineView(),
                  _ScheduleContent(),
                  _TasksContent(),
                  _NotesContent(),
                ],
              ),
            ),
            
            // Quick Add Buttons
            const SafeArea(
              top: false,
              child: QuickAddButtons(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact tab bar that won't overflow
class _TabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final int eventCount;
  final int taskCount;
  final int noteCount;

  const _TabBar({
    required this.selectedIndex,
    required this.onTabSelected,
    required this.eventCount,
    required this.taskCount,
    required this.noteCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTab(0, Icons.timeline, null),
          _buildTab(1, Icons.calendar_today, eventCount),
          _buildTab(2, Icons.check_box_outlined, taskCount),
          _buildTab(3, Icons.note, noteCount),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, int? count) {
    final isSelected = index == selectedIndex;
    final labels = ['Timeline', 'Schedule', 'Tasks', 'Notes'];
    
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? AppTheme.accentBlue : AppTheme.secondaryText,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    count != null ? '${labels[index]}($count)' : labels[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppTheme.primaryText : AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Schedule content wrapper
class _ScheduleContent extends ConsumerWidget {
  const _ScheduleContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      child: ScheduleSection(),
    );
  }
}

/// Tasks content wrapper
class _TasksContent extends ConsumerWidget {
  const _TasksContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      child: TasksSection(),
    );
  }
}

/// Notes content wrapper
class _NotesContent extends ConsumerWidget {
  const _NotesContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      child: NotesSection(),
    );
  }
}
