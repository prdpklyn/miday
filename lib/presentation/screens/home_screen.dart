
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/presentation/widgets/schedule_section.dart';
import 'package:my_day/presentation/widgets/tasks_section.dart';
import 'package:my_day/presentation/widgets/notes_section.dart';
import 'package:my_day/presentation/widgets/floating_ai_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final dateString = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Mi-day", style: AppTheme.heading1),
                            const SizedBox(height: 4),
                            Text(dateString, style: AppTheme.bodyRegular),
                          ],
                        ),
                        const CircleAvatar(
                          backgroundColor: Color(0xFFE3F2FD),
                          child: Text(
                            "JD",
                            style: TextStyle(
                              color: AppTheme.accentBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  const ScheduleSection(),
                  const SizedBox(height: 20),
                  const TasksSection(),
                  const SizedBox(height: 20),
                  const NotesSection(),
                  const SizedBox(height: 100), // Padding for bottom
                ],
              ),
            ),
          ),
          const FloatingAIButton(),
        ],
      ),
    );
  }
}
