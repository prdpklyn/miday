import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:my_day/data/sources/app_database.dart';
import 'package:my_day/services/ai/ai_service.dart';
import 'package:my_day/services/ai/function_handler.dart';
import 'package:my_day/services/litert_service.dart';
import 'package:my_day/services/voice_pipeline_service.dart';
import 'package:my_day/presentation/providers/chat_provider.dart';
import 'package:my_day/presentation/providers/data_providers.dart';

final appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final liteRTProvider = Provider<LiteRTService>((Ref ref) {
  final LiteRTService service = LiteRTService();
  // Initialize native bridge (loads models and speech recognizer)
  service.initialize();
  ref.onDispose(service.dispose);
  return service;
});

final StateNotifierProvider<VoicePipelineService, VoicePipelineState> voicePipelineProvider =
    StateNotifierProvider<VoicePipelineService, VoicePipelineState>((Ref ref) {
      final LiteRTService liteRT = ref.read(liteRTProvider);
      final AIService aiService = ref.read(aiServiceProvider);
      final FunctionHandler functionHandler = FunctionHandler(ref.read(databaseHelperProvider));
      final VoicePipelineService service = VoicePipelineService(
        liteRT: liteRT,
        processTranscript: (String transcript) async {
          // Use the same AI pipeline as the chat button
          final result = await aiService.processSmartQuery(transcript);

          if (!result.needsFunctionExecution || result.functionJson == null) {
            return null;
          }

          final funcResult = await functionHandler.handleExecution(result.functionJson!);

          // Refresh data providers so UI reflects the change
          ref.invalidate(tasksProvider);
          ref.invalidate(eventsProvider);
          ref.invalidate(notesProvider);

          if (!funcResult.success) {
            return null;
          }

          return funcResult.functionName;
        },
      );
      ref.onDispose(service.dispose);
      return service;
    });
