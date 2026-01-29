import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/speech_service.dart';

class MessageInput extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const MessageInput({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.onStop,
  });

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speechState = ref.watch(speechProvider);

    // 控制脉冲动画
    if (speechState.isListening) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.reset();
    }

    // 如果有识别结果，更新输入框
    if (speechState.recognizedText.isNotEmpty &&
        !speechState.isListening &&
        widget.controller.text != speechState.recognizedText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.text = speechState.recognizedText;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: speechState.recognizedText.length),
        );
        ref.read(speechProvider.notifier).clearRecognizedText();
      });
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 语音识别状态提示
          if (speechState.isListening || speechState.partialText.isNotEmpty)
            _buildVoiceIndicator(theme, speechState),
          
          Row(
            children: [
              // 语音输入按钮
              _buildVoiceButton(theme, speechState),
              const SizedBox(width: 8),
              // 文本输入框
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  enabled: !widget.isLoading && !speechState.isListening,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSend(),
                  decoration: InputDecoration(
                    hintText: speechState.isListening ? '正在聆听...' : '输入消息...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 发送/停止按钮
              _buildSendButton(theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceIndicator(ThemeData theme, SpeechServiceState speechState) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 音量指示器
          _buildSoundLevelIndicator(theme, speechState.soundLevel),
          const SizedBox(width: 12),
          // 识别中的文字
          Expanded(
            child: Text(
              speechState.partialText.isNotEmpty
                  ? speechState.partialText
                  : '请说话...',
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontStyle: speechState.partialText.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 取消按钮
          IconButton(
            onPressed: () {
              ref.read(speechProvider.notifier).cancelListening();
            },
            icon: const Icon(Icons.close),
            iconSize: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }

  Widget _buildSoundLevelIndicator(ThemeData theme, double level) {
    // 将音量等级转换为 0-1 范围
    final normalizedLevel = (level.clamp(-2, 10) + 2) / 12;
    
    return SizedBox(
      width: 40,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (index) {
          final threshold = (index + 1) / 4;
          final isActive = normalizedLevel >= threshold;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 4,
            height: isActive ? 16 + (normalizedLevel - threshold) * 8 : 8,
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onPrimaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVoiceButton(ThemeData theme, SpeechServiceState speechState) {
    final isListening = speechState.isListening;
    final isAvailable = speechState.speechStatus != SpeechStatus.unavailable &&
        speechState.speechStatus != SpeechStatus.uninitialized;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isListening ? _pulseAnimation.value : 1.0,
          child: Container(
            decoration: isListening
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: IconButton(
              onPressed: widget.isLoading || !isAvailable
                  ? null
                  : () {
                      if (isListening) {
                        ref.read(speechProvider.notifier).stopListening();
                      } else {
                        ref.read(speechProvider.notifier).startListening();
                      }
                    },
              icon: Icon(
                isListening ? Icons.mic : Icons.mic_none,
              ),
              style: IconButton.styleFrom(
                backgroundColor: isListening
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: isListening
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    if (widget.isLoading) {
      return IconButton.filled(
        onPressed: widget.onStop,
        icon: const Icon(Icons.stop),
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
        ),
      );
    }

    return IconButton.filled(
      onPressed: widget.onSend,
      icon: const Icon(Icons.send),
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }
}
