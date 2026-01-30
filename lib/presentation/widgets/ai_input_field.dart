import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/presentation/providers/data_providers.dart';
import 'package:my_day/presentation/providers/chat_provider.dart';
import 'package:my_day/services/ai/function_handler.dart';
import 'package:my_day/services/ai/response_generator.dart';

final responseGeneratorForInputProvider = Provider((ref) => ResponseGenerator());
final functionHandlerForInputProvider = Provider((ref) => FunctionHandler(ref.read(databaseHelperProvider)));

// Using a simple Notifier for boolean state
final aiProcessingProvider = NotifierProvider<AiProcessingNotifier, bool>(() {
  return AiProcessingNotifier();
});

class AiProcessingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void setProcessing(bool value) => state = value;
}

class AIInputField extends ConsumerStatefulWidget {
  const AIInputField({super.key});

  @override
  ConsumerState<AIInputField> createState() => _AIInputFieldState();
}

class _AIInputFieldState extends ConsumerState<AIInputField> {
  final TextEditingController _controller = TextEditingController();

  void _handleSubmit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(aiProcessingProvider.notifier).setProcessing(true);
    _controller.clear();

    try {
      final aiService = ref.read(aiServiceProvider);
      final functionHandler = ref.read(functionHandlerForInputProvider);
      final responseGenerator = ref.read(responseGeneratorForInputProvider);

      // Use smart query processing
      final result = await aiService.processSmartQuery(text);
      
      // Handle conversational intents
      if (result.conversationalIntent != null && !result.needsFunctionExecution) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseGenerator.conversationalResponse(result.conversationalIntent!)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Handle function execution
      if (result.needsFunctionExecution && result.functionJson != null) {
        final funcResult = await functionHandler.handleExecution(result.functionJson!);
        
        // Refresh all providers to show new data
        ref.invalidate(tasksProvider);
        ref.invalidate(eventsProvider);
        ref.invalidate(notesProvider);
        
        if (mounted) {
          String message;
          if (funcResult.success) {
            switch (funcResult.functionName) {
              case 'create_task':
                message = responseGenerator.taskCreated(
                  title: funcResult.data['title'] ?? 'Task',
                  priority: funcResult.data['priority'],
                );
                break;
              case 'create_event':
                message = responseGenerator.eventCreated(
                  title: funcResult.data['title'] ?? 'Event',
                  startTime: funcResult.data['startTime'] != null 
                      ? DateTime.tryParse(funcResult.data['startTime']) ?? DateTime.now()
                      : DateTime.now(),
                );
                break;
              case 'create_note':
                message = responseGenerator.noteCreated(
                  title: funcResult.data['title'] ?? 'Note',
                );
                break;
              default:
                message = "✓ Done!";
            }
          } else {
            message = responseGenerator.errorResponse();
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseGenerator.conversationalResponse('unknown')),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      ref.read(aiProcessingProvider.notifier).setProcessing(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = ref.watch(aiProcessingProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  enabled: !isProcessing,
                  decoration: const InputDecoration(
                    hintText: "Try 'Add a task' or 'What's my schedule?'",
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  onSubmitted: (_) => _handleSubmit(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              onPressed: isProcessing ? null : _handleSubmit,
              mini: true,
              backgroundColor: Colors.black,
              child: isProcessing 
                ? const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
