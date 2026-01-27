
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/presentation/providers/data_providers.dart';
import 'package:my_day/services/ai/ai_service.dart';
import 'package:my_day/services/ai/function_handler.dart';

final aiServiceProvider = Provider((ref) => AIService());
final functionHandlerProvider = Provider((ref) => FunctionHandler(ref.read(databaseHelperProvider)));

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
      final functionHandler = ref.read(functionHandlerProvider);

      final jsonResult = await aiService.processQuery(text);
      
      if (jsonResult != null) {
        await functionHandler.handleExecution(jsonResult);
        
        // Refresh all providers to show new data
        ref.invalidate(tasksProvider);
        ref.invalidate(eventsProvider);
        ref.invalidate(notesProvider);
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not understand request.")),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea( // Check for bottom notch
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
                    hintText: "Ask to create a task, note, or event...",
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
              backgroundColor: Colors.black, // Dark accent
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
