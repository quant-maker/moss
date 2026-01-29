import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../llm/llm_provider.dart';
import '../llm/llm_router.dart';
import '../llm/models/message.dart';
import '../models/conversation_memory.dart';

/// 上下文压缩配置
class CompressionConfig {
  /// 最大 token 数（触发压缩的阈值）
  final int maxTokens;

  /// 保留的最近消息数
  final int keepRecentMessages;

  /// 压缩后的目标 token 数
  final int targetTokens;

  /// 记忆的最大 token 数
  final int maxMemoryTokens;

  const CompressionConfig({
    this.maxTokens = 6000,
    this.keepRecentMessages = 10,
    this.targetTokens = 4000,
    this.maxMemoryTokens = 1500,
  });
}

/// 压缩结果
class CompressionResult {
  final bool wasCompressed;
  final List<Message> messages;
  final ConversationMemory? memory;
  final int originalTokens;
  final int finalTokens;
  final String? error;

  CompressionResult({
    required this.wasCompressed,
    required this.messages,
    this.memory,
    required this.originalTokens,
    required this.finalTokens,
    this.error,
  });

  factory CompressionResult.noChange(List<Message> messages, int tokens) {
    return CompressionResult(
      wasCompressed: false,
      messages: messages,
      originalTokens: tokens,
      finalTokens: tokens,
    );
  }

  factory CompressionResult.error(String error, List<Message> messages) {
    return CompressionResult(
      wasCompressed: false,
      messages: messages,
      originalTokens: 0,
      finalTokens: 0,
      error: error,
    );
  }
}

/// 上下文压缩器服务
/// 实现智能对话压缩，提取关键信息，实现"无限上下文"
class ContextCompressor {
  static const String _boxName = 'conversation_memories';
  Box<ConversationMemory>? _box;
  bool _initialized = false;
  
  final CompressionConfig config;

  ContextCompressor({this.config = const CompressionConfig()});

  /// 初始化
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (!Hive.isAdapterRegistered(12)) {
        Hive.registerAdapter(MemoryItemAdapter());
      }
      if (!Hive.isAdapterRegistered(13)) {
        Hive.registerAdapter(ConversationMemoryAdapter());
      }
      _box = await Hive.openBox<ConversationMemory>(_boxName);
      _initialized = true;
      debugPrint('[ContextCompressor] Initialized');
    } catch (e) {
      debugPrint('[ContextCompressor] Initialize error: $e');
    }
  }

  /// 估算消息列表的 token 数
  int estimateTokens(List<Message> messages) {
    int total = 0;
    for (final msg in messages) {
      // 简单估算：中文约每字 2 token，英文约每词 1 token
      // 这里使用简化的估算方法
      total += (msg.content.length * 0.5).round();
      if (msg.toolCalls != null) {
        total += 100 * msg.toolCalls!.length; // 工具调用额外估算
      }
    }
    return total;
  }

  /// 检查是否需要压缩
  bool needsCompression(List<Message> messages) {
    final tokens = estimateTokens(messages);
    return tokens > config.maxTokens;
  }

  /// 压缩上下文
  /// 使用 LLM 生成摘要和提取关键信息
  Future<CompressionResult> compress({
    required String conversationId,
    required List<Message> messages,
    required LLMProvider llmProvider,
  }) async {
    await initialize();

    final originalTokens = estimateTokens(messages);

    // 如果不需要压缩，直接返回
    if (originalTokens <= config.maxTokens) {
      return CompressionResult.noChange(messages, originalTokens);
    }

    debugPrint(
        '[ContextCompressor] Compressing: $originalTokens tokens -> target ${config.targetTokens}');

    try {
      // 分离要保留的最近消息和要压缩的历史消息
      final recentMessages = messages.length > config.keepRecentMessages
          ? messages.sublist(messages.length - config.keepRecentMessages)
          : messages;

      final historyMessages = messages.length > config.keepRecentMessages
          ? messages.sublist(0, messages.length - config.keepRecentMessages)
          : <Message>[];

      if (historyMessages.isEmpty) {
        // 没有足够的历史消息需要压缩
        return CompressionResult.noChange(messages, originalTokens);
      }

      // 获取或创建记忆
      var memory = getMemory(conversationId);
      final isNewMemory = memory == null;
      
      memory ??= ConversationMemory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: conversationId,
        summary: '',
      );

      // 使用 LLM 生成摘要和提取关键信息
      final compressionResult = await _generateSummaryWithLLM(
        historyMessages,
        memory,
        llmProvider,
      );

      if (compressionResult == null) {
        return CompressionResult.error('Failed to generate summary', messages);
      }

      // 更新记忆
      memory = compressionResult;
      memory = memory.copyWith(
        originalMessageCount: memory.originalMessageCount + historyMessages.length,
        compressedAt: messages.length - config.keepRecentMessages,
      );

      // 保存记忆
      await _box!.put(conversationId, memory);

      // 构建压缩后的消息列表
      final compressedMessages = _buildCompressedMessages(memory, recentMessages);

      final finalTokens = estimateTokens(compressedMessages);

      debugPrint(
          '[ContextCompressor] Compressed: $originalTokens -> $finalTokens tokens');

      return CompressionResult(
        wasCompressed: true,
        messages: compressedMessages,
        memory: memory,
        originalTokens: originalTokens,
        finalTokens: finalTokens,
      );
    } catch (e) {
      debugPrint('[ContextCompressor] Compression error: $e');
      return CompressionResult.error(e.toString(), messages);
    }
  }

  /// 使用 LLM 生成摘要和提取关键信息
  Future<ConversationMemory?> _generateSummaryWithLLM(
    List<Message> historyMessages,
    ConversationMemory existingMemory,
    LLMProvider llmProvider,
  ) async {
    // 构建提取信息的提示
    final extractionPrompt = '''请分析以下对话历史，提取关键信息并生成摘要。

## 要求
1. 生成一个简洁的对话摘要（100-200字）
2. 提取关键结论（如果有）
3. 识别用户偏好和需求
4. 记录重要的技术决策（如果适用）
5. 识别重要的实体（人名、项目名、地点等）

## 对话历史
${_formatMessagesForExtraction(historyMessages)}

${existingMemory.summary.isNotEmpty ? '''
## 之前的对话摘要
${existingMemory.summary}
''' : ''}

## 输出格式（请严格按照此格式输出）
### 摘要
[对话摘要]

### 关键结论
- [结论1]
- [结论2]

### 用户偏好
- [偏好1]
- [偏好2]

### 技术决策
- [决策1]
- [决策2]

### 重要实体
- [实体1]
- [实体2]
''';

    try {
      final response = await llmProvider.chat([
        Message.system('你是一个信息提取助手，专门从对话中提取关键信息。请准确、简洁地完成任务。'),
        Message.user(extractionPrompt),
      ]);

      if (response.message.content.isEmpty) {
        return null;
      }

      // 解析 LLM 输出
      return _parseExtractionResult(
        response.message.content,
        existingMemory,
      );
    } catch (e) {
      debugPrint('[ContextCompressor] LLM extraction error: $e');
      
      // 如果 LLM 调用失败，使用简单的规则提取
      return _simpleExtraction(historyMessages, existingMemory);
    }
  }

  /// 格式化消息用于提取
  String _formatMessagesForExtraction(List<Message> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      final role = msg.role == MessageRole.user ? '用户' : '助手';
      buffer.writeln('$role: ${msg.content}');
    }
    return buffer.toString();
  }

  /// 解析 LLM 的提取结果
  ConversationMemory _parseExtractionResult(
    String content,
    ConversationMemory existingMemory,
  ) {
    final memories = List<MemoryItem>.from(existingMemory.memories);
    String summary = existingMemory.summary;

    // 解析摘要
    final summaryMatch = RegExp(r'### 摘要\s*\n([\s\S]*?)(?=###|$)').firstMatch(content);
    if (summaryMatch != null) {
      final newSummary = summaryMatch.group(1)?.trim() ?? '';
      if (newSummary.isNotEmpty) {
        // 合并新旧摘要
        summary = existingMemory.summary.isEmpty
            ? newSummary
            : '${existingMemory.summary}\n\n---\n\n$newSummary';
        // 限制摘要长度
        if (summary.length > 1000) {
          summary = summary.substring(summary.length - 1000);
        }
      }
    }

    // 解析各类记忆项
    _parseMemorySection(content, '### 关键结论', MemoryType.conclusion, memories);
    _parseMemorySection(content, '### 用户偏好', MemoryType.preference, memories);
    _parseMemorySection(content, '### 技术决策', MemoryType.decision, memories);
    _parseMemorySection(content, '### 重要实体', MemoryType.entity, memories);

    return existingMemory.copyWith(
      summary: summary,
      memories: memories,
    );
  }

  /// 解析记忆项部分
  void _parseMemorySection(
    String content,
    String sectionHeader,
    MemoryType type,
    List<MemoryItem> memories,
  ) {
    final pattern = RegExp('$sectionHeader\\s*\\n([\\s\\S]*?)(?=###|\$)');
    final match = pattern.firstMatch(content);
    if (match != null) {
      final section = match.group(1) ?? '';
      final lines = section.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('-') || trimmed.startsWith('*')) {
          final itemContent = trimmed.substring(1).trim();
          if (itemContent.isNotEmpty && itemContent != '[无]') {
            // 检查是否已存在相似的记忆
            final exists = memories.any((m) =>
                m.type == type &&
                _isSimilar(m.content, itemContent));
            if (!exists) {
              memories.add(MemoryItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                content: itemContent,
                typeIndex: type.index,
                importance: _calculateImportance(type),
              ));
            }
          }
        }
      }
    }
  }

  /// 简单的相似度检查
  bool _isSimilar(String a, String b) {
    final normalizedA = a.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final normalizedB = b.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return normalizedA == normalizedB ||
        normalizedA.contains(normalizedB) ||
        normalizedB.contains(normalizedA);
  }

  /// 计算初始重要性
  double _calculateImportance(MemoryType type) {
    switch (type) {
      case MemoryType.summary:
        return 0.9;
      case MemoryType.conclusion:
        return 0.8;
      case MemoryType.preference:
        return 0.7;
      case MemoryType.decision:
        return 0.85;
      case MemoryType.entity:
        return 0.6;
    }
  }

  /// 简单规则提取（备用方案）
  ConversationMemory _simpleExtraction(
    List<Message> messages,
    ConversationMemory existingMemory,
  ) {
    final buffer = StringBuffer();
    if (existingMemory.summary.isNotEmpty) {
      buffer.writeln(existingMemory.summary);
      buffer.writeln('\n---\n');
    }
    
    // 简单摘要：取前几条和后几条消息
    final messageCount = messages.length;
    buffer.writeln('对话包含 $messageCount 条消息。');
    
    if (messages.isNotEmpty) {
      buffer.writeln('开始话题: ${messages.first.content.substring(0, messages.first.content.length.clamp(0, 100))}...');
    }
    if (messages.length > 2) {
      final lastUserMsg = messages.lastWhere(
        (m) => m.role == MessageRole.user,
        orElse: () => messages.last,
      );
      buffer.writeln('最近话题: ${lastUserMsg.content.substring(0, lastUserMsg.content.length.clamp(0, 100))}...');
    }

    return existingMemory.copyWith(summary: buffer.toString());
  }

  /// 构建压缩后的消息列表
  List<Message> _buildCompressedMessages(
    ConversationMemory memory,
    List<Message> recentMessages,
  ) {
    final result = <Message>[];

    // 添加记忆作为系统消息
    final memoryText = memory.toPromptText();
    if (memoryText.isNotEmpty) {
      result.add(Message.system('''以下是之前对话的重要信息，请在回复时参考：

$memoryText

---

请基于以上背景信息继续对话。'''));
    }

    // 添加最近的消息
    result.addAll(recentMessages);

    return result;
  }

  /// 获取对话记忆
  ConversationMemory? getMemory(String conversationId) {
    return _box?.get(conversationId);
  }

  /// 删除对话记忆
  Future<void> deleteMemory(String conversationId) async {
    await initialize();
    await _box?.delete(conversationId);
  }

  /// 清理所有记忆
  Future<void> clearAll() async {
    await initialize();
    await _box?.clear();
  }

  /// 获取记忆统计
  MemoryStats? getStats(String conversationId) {
    final memory = getMemory(conversationId);
    if (memory == null) return null;
    return MemoryStats.fromMemory(memory);
  }
}

/// ContextCompressor Provider
final contextCompressorProvider = Provider<ContextCompressor>((ref) {
  return ContextCompressor();
});

/// 压缩配置 Provider
final compressionConfigProvider = Provider<CompressionConfig>((ref) {
  return const CompressionConfig();
});
