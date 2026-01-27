import 'package:riverpod/riverpod.dart';

// Home screen state for managing section expansion
class HomeState {
  final bool isScheduleExpanded;
  final bool isTasksExpanded;
  final bool isNotesExpanded;

  const HomeState({
    this.isScheduleExpanded = true,
    this.isTasksExpanded = true,
    this.isNotesExpanded = false, // Notes collapsed by default
  });

  HomeState copyWith({
    bool? isScheduleExpanded,
    bool? isTasksExpanded,
    bool? isNotesExpanded,
  }) {
    return HomeState(
      isScheduleExpanded: isScheduleExpanded ?? this.isScheduleExpanded,
      isTasksExpanded: isTasksExpanded ?? this.isTasksExpanded,
      isNotesExpanded: isNotesExpanded ?? this.isNotesExpanded,
    );
  }
}

// Provider for home screen state - using NotifierProvider with Notifier for mutable state in memory
class HomeStateNotifier extends Notifier<HomeState> {
  @override
  HomeState build() => const HomeState();
}

final homeStateProvider = NotifierProvider<HomeStateNotifier, HomeState>(() {
  return HomeStateNotifier();
});
