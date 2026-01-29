import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/llm/models/message.dart';
import '../../../core/services/speech_service.dart';

class MessageBubble extends ConsumerWidget {
  final String content;
  final bool isUser;
  final bool isStreaming;
  final List<ToolCall>? toolCalls;
  final VoidCallback? onRegenerate;

  const MessageBubble({
    super.key,
    required this.content,
    required this.isUser,
    this.isStreaming = false,
    this.toolCalls,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final speechState = ref.watch(speechProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(theme, isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 工具调用显示
                      if (toolCalls != null && toolCalls!.isNotEmpty)
                        _buildToolCalls(theme),

                      // 消息内容
                      if (content.isNotEmpty)
                        isUser
                            ? Text(
                                content,
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : MarkdownBody(
                                data: content,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  code: TextStyle(
                                    backgroundColor: theme.colorScheme.surface,
                                    color: theme.colorScheme.primary,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),

                      // 流式加载指示器
                      if (isStreaming)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 操作按钮 (仅 AI 消息)
                if (!isUser && !isStreaming && content.isNotEmpty)
                  _buildActionButtons(context, ref, theme, speechState),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(theme, isUser: true),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref,
      ThemeData theme, SpeechServiceState speechState) {
    final isSpeaking = speechState.isPlaying;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 复制按钮
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已复制到剪贴板'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: '复制',
          ),

          // 朗读按钮
          IconButton(
            onPressed: speechState.ttsStatus == TtsStatus.uninitialized
                ? null
                : () {
                    if (isSpeaking) {
                      ref.read(speechProvider.notifier).stopSpeaking();
                    } else {
                      // 移除 Markdown 格式后朗读
                      final plainText = _stripMarkdown(content);
                      ref.read(speechProvider.notifier).speak(plainText);
                    }
                  },
            icon: Icon(
              isSpeaking ? Icons.stop : Icons.volume_up,
              size: 18,
            ),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: isSpeaking
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            tooltip: isSpeaking ? '停止朗读' : '朗读',
          ),

          // 重新生成按钮
          if (onRegenerate != null)
            IconButton(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh, size: 18),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              color: theme.colorScheme.onSurfaceVariant,
              tooltip: '重新生成',
            ),
        ],
      ),
    );
  }

  /// 移除 Markdown 格式
  String _stripMarkdown(String markdown) {
    var text = markdown;
    // 移除代码块
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    // 移除行内代码
    text = text.replaceAll(RegExp(r'`[^`]*`'), '');
    // 移除链接
    text = text.replaceAllMapped(
        RegExp(r'\[([^\]]*)\]\([^\)]*\)'), (m) => m.group(1) ?? '');
    // 移除加粗
    text = text.replaceAllMapped(
        RegExp(r'\*\*([^\*]*)\*\*'), (m) => m.group(1) ?? '');
    // 移除斜体
    text = text.replaceAllMapped(
        RegExp(r'\*([^\*]*)\*'), (m) => m.group(1) ?? '');
    // 移除标题标记
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // 移除列表标记
    text = text.replaceAll(RegExp(r'^[\-\*]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
    // 移除多余空行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  Widget _buildAvatar(ThemeData theme, {required bool isUser}) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.primaryContainer,
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: 18,
        color: isUser
            ? theme.colorScheme.onSecondaryContainer
            : theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildToolCalls(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '正在执行操作...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...toolCalls!.map((tc) => Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Text(
                  '${tc.name}(${tc.arguments})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontFamily: 'monospace',
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
