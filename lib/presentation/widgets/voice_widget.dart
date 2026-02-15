import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/presentation/providers/voice_pipeline_provider.dart';
import 'package:my_day/presentation/widgets/waveform_visualizer.dart';
import 'package:my_day/services/voice_pipeline_service.dart';

class VoiceWidget extends ConsumerWidget {
  const VoiceWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VoicePipelineState state = ref.watch(voicePipelineProvider);
    final bool isListening = state.state == VoiceState.listening;
    final bool isProcessing = state.state == VoiceState.processing;
    final bool isRequestingPermission = state.state == VoiceState.requestingPermission;
    final bool isExecuting = state.state == VoiceState.executing;
    final bool isBusy = isListening || isProcessing || isRequestingPermission || isExecuting;

    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: () {
            if (state.state == VoiceState.idle || state.state == VoiceState.error) {
              ref.read(voicePipelineProvider.notifier).startListening();
            } else if (state.state == VoiceState.listening) {
              ref.read(voicePipelineProvider.notifier).cancel();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(isBusy ? 16 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isBusy
                ? AppTheme.accentBlue.withValues(alpha: 0.1)
                : Colors.white,
              border: Border.all(
                color: isBusy
                  ? AppTheme.accentBlue.withValues(alpha: 0.3)
                  : Colors.grey.shade300,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isRequestingPermission
              ? _buildRequestingPermissionState()
              : isBusy
                ? _buildListeningState(state)
                : _buildIdleState(),
          ),
        ),
        if (state.state == VoiceState.complete) 
          _buildConfirmation(state),
        if (state.state == VoiceState.error)
          _buildError(state.error ?? 'Unknown error'),
      ],
    );
  }

  Widget _buildIdleState() {
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.accentBlue, Colors.purple],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.mic, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Tap to speak',
                style: TextStyle(
                  color: AppTheme.primaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '"Schedule a meeting", "Add task", "Quick note"',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(Icons.keyboard_voice, color: Colors.grey.shade400, size: 20),
      ],
    );
  }

  Widget _buildRequestingPermissionState() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Requesting microphone access...',
          style: TextStyle(
            color: AppTheme.accentBlue,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildListeningState(VoicePipelineState state) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppTheme.accentBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Text(
              state.state == VoiceState.processing ? 'Processing...' : 'Listening...',
              style: TextStyle(
                color: AppTheme.accentBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(height: 40, child: WaveformVisualizer(levels: state.audioLevels)),
        if (state.transcript != null) ...[
          const SizedBox(height: 12),
          Text(
            state.transcript!,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
        if (state.intent != null && state.confidence != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getIntentColor(state.intent!).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_getIntentLabel(state.intent!)} (${(state.confidence! * 100).toInt()}%)',
              style: TextStyle(
                color: _getIntentColor(state.intent!),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Tap to cancel',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildConfirmation(VoicePipelineState state) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Done!',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  state.functionCall?.name ?? '',
                  style: TextStyle(color: Colors.green.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _getIntentLabel(String intent) {
    switch (intent) {
      case 'add_event': return 'New Event';
      case 'reschedule_event': return 'Reschedule';
      case 'cancel_event': return 'Cancel Event';
      case 'add_task': return 'New Task';
      case 'complete_task': return 'Complete Task';
      case 'defer_task': return 'Defer Task';
      case 'create_note': return 'New Note';
      case 'append_note': return 'Add to Note';
      case 'search_notes': return 'Search Notes';
      default: return intent;
    }
  }

  Color _getIntentColor(String intent) {
    switch (intent) {
      case 'add_event':
      case 'reschedule_event':
      case 'cancel_event':
        return AppTheme.accentBlue;
      case 'add_task':
      case 'complete_task':
      case 'defer_task':
        return Colors.amber.shade700;
      case 'create_note':
      case 'append_note':
      case 'search_notes':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
