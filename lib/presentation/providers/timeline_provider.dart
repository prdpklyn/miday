import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/data/sources/app_database.dart';
import 'package:my_day/presentation/providers/voice_pipeline_provider.dart';

final FutureProvider<List<TimelineItem>> timelineProvider = FutureProvider<List<TimelineItem>>((Ref ref) async {
  final AppDatabase database = ref.read(appDatabaseProvider);
  final DateTime date = DateTime.now();
  return database.getTimelineForDate(date);
});
