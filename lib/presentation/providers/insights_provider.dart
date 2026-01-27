import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/presentation/providers/data_providers.dart';

// Insights data model
class InsightsData {
  final int productivityScore;
  final int tasksCompletedThisWeek;
  final int totalTasks;
  final String aiInsight;
  final Map<String, int> completionByDay;

  InsightsData({
    required this.productivityScore,
    required this.tasksCompletedThisWeek,
    required this.totalTasks,
    required this.aiInsight,
    required this.completionByDay,
  });
}

// Provider that computes insights from existing data
final insightsProvider = Provider<AsyncValue<InsightsData>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  
  return tasksAsync.when(
    data: (tasks) {
      final completed = tasks.where((t) => t.isCompleted).length;
      final total = tasks.length;
      final score = total > 0 ? ((completed / total) * 100).round() : 0;
      
      // Simple AI insight based on completion rate
      String insight;
      if (score >= 80) {
        insight = "🎉 Excellent work! You're crushing your goals.";
      } else if (score >= 50) {
        insight = "💪 Good progress! Keep pushing forward.";
      } else {
        insight = "🌱 Every step counts. Let's build momentum!";
      }

      return AsyncValue.data(InsightsData(
        productivityScore: score,
        tasksCompletedThisWeek: completed,
        totalTasks: total,
        aiInsight: insight,
        completionByDay: {
          'Mon': 0,
          'Tue': 0,
          'Wed': 0,
          'Thu': 0,
          'Fri': 0,
          'Sat': 0,
          'Sun': 0,
        },
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});
