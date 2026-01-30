import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/presentation/providers/chat_provider.dart';
import 'package:my_day/presentation/providers/voice_provider.dart';
import 'package:my_day/services/ai/chat_service.dart';

class FloatingAIButton extends ConsumerWidget {
  const FloatingAIButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: GestureDetector(
        onTap: () {
          ref.read(chatProvider.notifier).openChat();
          _showChatOverlay(context, ref);
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF8B7CF6), Color(0xFF4EA8DE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B7CF6).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  void _showChatOverlay(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AIChatOverlay(),
    ).then((_) {
      ref.read(chatProvider.notifier).closeChat();
    });
  }
}

class AIChatOverlay extends ConsumerStatefulWidget {
  const AIChatOverlay({super.key});

  @override
  ConsumerState<AIChatOverlay> createState() => _AIChatOverlayState();
}

class _AIChatOverlayState extends ConsumerState<AIChatOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatProvider);
    final voiceAsync = ref.watch(voiceProvider);

    return chatAsync.when(
      data: (chatState) => voiceAsync.when(
        data: (voiceState) => _buildChatUI(context, chatState, voiceState),
        loading: () => _buildChatUI(context, chatState, const VoiceState()),
        error: (_, __) => _buildChatUI(context, chatState, const VoiceState()),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildChatUI(
      BuildContext context, ChatState chatState, VoiceState voiceState) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with voice mode toggle
          _buildHeader(voiceState),

          // Messages
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Loading/Recording/Transcribing indicator
          _buildStatusIndicator(chatState, voiceState),

          // Input field with voice button
          _buildInputArea(voiceState),
        ],
      ),
    );
  }

  Widget _buildHeader(VoiceState voiceState) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF8B7CF6), Color(0xFF4EA8DE)],
              ),
            ),
            child:
                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'AI Assistant',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Voice mode toggle
          IconButton(
            icon: Icon(
              voiceState.isVoiceModeEnabled
                  ? Icons.volume_up
                  : Icons.volume_off,
              color: voiceState.isVoiceModeEnabled
                  ? const Color(0xFF8B7CF6)
                  : Colors.grey,
            ),
            tooltip: voiceState.isVoiceModeEnabled
                ? 'Voice mode on'
                : 'Voice mode off',
            onPressed: () {
              ref.read(voiceProvider.notifier).toggleVoiceMode();
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(ChatState chatState, VoiceState voiceState) {
    // Show recording indicator
    if (voiceState.isRecording) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red
                        .withOpacity(0.5 + _pulseController.value * 0.5),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Recording... Tap mic to stop',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        },
      );
    }

    // Show transcribing indicator
    if (voiceState.isTranscribing) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation(Colors.orange.withOpacity(0.8)),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Transcribing...',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
      );
    }

    // Show speaking indicator
    if (voiceState.isSpeaking) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volume_up, color: const Color(0xFF8B7CF6), size: 20),
            const SizedBox(width: 12),
            const Text(
              'Speaking...',
              style: TextStyle(color: Color(0xFF8B7CF6)),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => ref.read(voiceProvider.notifier).stopSpeaking(),
              child: const Text('Stop'),
            ),
          ],
        ),
      );
    }

    // Show thinking indicator
    if (chatState.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation(const Color(0xFF8B7CF6)),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Thinking...'),
          ],
        ),
      );
    }

    // Show error if any
    if (voiceState.error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                voiceState.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => ref.read(voiceProvider.notifier).clearError(),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInputArea(VoiceState voiceState) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: voiceState.isRecording
                    ? 'Recording...'
                    : 'Type or tap mic to speak...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              enabled: !voiceState.isRecording && !voiceState.isTranscribing,
            ),
          ),
          const SizedBox(width: 8),
          // Microphone button
          _buildMicButton(voiceState),
          const SizedBox(width: 8),
          // Send button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF8B7CF6), Color(0xFF4EA8DE)],
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: voiceState.isProcessing ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(VoiceState voiceState) {
    final isRecording = voiceState.isRecording;
    final isProcessing = voiceState.isTranscribing;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRecording
                ? Colors.red.withOpacity(0.8 + _pulseController.value * 0.2)
                : isProcessing
                    ? Colors.orange
                    : Colors.grey[200],
          ),
          child: IconButton(
            icon: Icon(
              isRecording
                  ? Icons.stop
                  : isProcessing
                      ? Icons.hourglass_top
                      : Icons.mic,
              color: isRecording || isProcessing ? Colors.white : Colors.grey[700],
            ),
            onPressed: isProcessing ? null : _handleMicPress,
          ),
        );
      },
    );
  }

  Future<void> _handleMicPress() async {
    final voiceNotifier = ref.read(voiceProvider.notifier);
    final voiceAsync = ref.read(voiceProvider);
    final voiceState = voiceAsync.hasValue ? voiceAsync.value : null;

    if (voiceState?.isRecording ?? false) {
      // Stop recording and get transcription
      final transcription = await voiceNotifier.stopRecording();
      if (transcription != null && transcription.isNotEmpty) {
        _controller.text = transcription;
        // Auto-send if voice mode is enabled
        final voiceAsyncNow = ref.read(voiceProvider);
        final isVoiceMode = voiceAsyncNow.hasValue && voiceAsyncNow.value!.isVoiceModeEnabled;
        if (isVoiceMode) {
          _sendMessage();
        }
      }
    } else {
      // Start recording
      await voiceNotifier.startRecording();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8B7CF6).withOpacity(0.1),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 40,
              color: Color(0xFF8B7CF6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Hi! How can I help?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Try asking me to:',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          _buildSuggestionChip('Add a task'),
          _buildSuggestionChip('Schedule an event'),
          _buildSuggestionChip("What's my schedule?"),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ActionChip(
        label: Text(text),
        onPressed: () {
          _controller.text = text;
        },
        backgroundColor: Colors.grey[100],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color:
              message.isUser ? const Color(0xFF8B7CF6) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final messageText = _controller.text;
    _controller.clear();

    final navigationHandler = ref.read(navigationHandlerProvider);
    await ref.read(chatProvider.notifier).sendMessage(
      messageText,
      onNavigationIntent: (String destination) {
        navigationHandler.navigateTo(context, destination);
        Navigator.of(context).pop();
      },
    );

    // Scroll to bottom after message is added
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    // Speak the AI response if voice mode is enabled
    final voiceAsync = ref.read(voiceProvider);
    final isVoiceMode = voiceAsync.hasValue && voiceAsync.value!.isVoiceModeEnabled;
    if (isVoiceMode) {
      // Wait a bit for the response to be added
      await Future.delayed(const Duration(milliseconds: 500));
      final chatAsync = ref.read(chatProvider);
      if (chatAsync.hasValue && chatAsync.value!.messages.isNotEmpty) {
        final lastMessage = chatAsync.value!.messages.last;
        if (!lastMessage.isUser) {
          await ref.read(voiceProvider.notifier).speak(lastMessage.text);
        }
      }
    }
  }
}
