import 'package:flutter/material.dart';
import 'package:my_day/presentation/screens/calendar_screen.dart';
import 'package:my_day/presentation/screens/notes_screen.dart';
import 'package:my_day/presentation/screens/habits_screen.dart';
import 'package:my_day/presentation/screens/insights_screen.dart';

class NavigationHandler {
  /// Check if the user input contains navigation intent
  bool hasNavigationIntent(String input) {
    final lowerInput = input.toLowerCase();
    return lowerInput.contains('show') ||
        lowerInput.contains('open') ||
        lowerInput.contains('go to') ||
        lowerInput.contains('navigate');
  }

  /// Extract destination from user input
  String? extractDestination(String input) {
    final lowerInput = input.toLowerCase();
    
    if (lowerInput.contains('calendar')) return 'calendar';
    if (lowerInput.contains('note')) return 'notes';
    if (lowerInput.contains('habit')) return 'habits';
    if (lowerInput.contains('insight') || lowerInput.contains('analytic')) return 'insights';
    if (lowerInput.contains('home')) return 'home';
    
    return null;
  }

  /// Navigate to the specified destination
  void navigateTo(BuildContext context, String destination) {
    switch (destination.toLowerCase()) {
      case 'calendar':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CalendarScreen()),
        );
        break;
      case 'notes':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotesScreen()),
        );
        break;
      case 'habits':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HabitsScreen()),
        );
        break;
      case 'insights':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InsightsScreen()),
        );
        break;
      case 'home':
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      default:
        // Do nothing for unknown destinations
        break;
    }
  }
}
