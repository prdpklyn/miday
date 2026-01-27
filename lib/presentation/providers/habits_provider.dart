import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/data/models/habit_model.dart';
import 'package:my_day/data/sources/database_helper.dart';
import 'package:my_day/presentation/providers/data_providers.dart';
import 'package:uuid/uuid.dart';

// Habits Provider
final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<HabitModel>>(() {
  return HabitsNotifier();
});

class HabitsNotifier extends AsyncNotifier<List<HabitModel>> {
  late DatabaseHelper _db;

  @override
  Future<List<HabitModel>> build() async {
    _db = ref.read(databaseHelperProvider);
    return await _db.getAllHabits();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _db.getAllHabits());
  }

  Future<void> logCompletion(String habitId) async {
    final habitLog = HabitLog(
      id: const Uuid().v4(),
      habitId: habitId,
      completedAt: DateTime.now(),
    );
    await _db.logHabitCompletion(habitLog);
    await refresh();
  }

  Future<void> createHabit(HabitModel habit) async {
    await _db.createHabit(habit);
    await refresh();
  }
}
