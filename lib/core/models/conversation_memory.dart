import 'package:hive/hive.dart';

part 'conversation_memory.g.dart';

/// 对话记忆类型
enum MemoryType {
  /// 对话摘要
  summary,

  /// 关键结论
  conclusion,

  /// 用户偏好
  preference,

  /// 技术决策
  decision,

  /// 重要实体（人名、地点、项目等）
  entity,
}

/// 记忆项
@HiveType(typeId: 12)
class MemoryItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String content;

  @HiveField(2)
  int typeIndex;

  @HiveField(3)
  double importance;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime? lastAccessedAt;

  @HiveField(6)
  int accessCount;

  @HiveField(7)
  Map<String, String>? metadata;

  MemoryItem({
    required this.id,
    required this.content,
    this.typeIndex = 0,
    this.importance = 0.5,
    DateTime? createdAt,
    this.lastAccessedAt,
    this.accessCount = 0,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  MemoryType get type => MemoryType.values[typeIndex];
  set type(MemoryType value) => typeIndex = value.index;

  /// 访问此记忆项
  void access() {
    accessCount++;
    lastAccessedAt = DateTime.now();
  }

  /// 更新重要性
  void updateImportance(double delta) {
    importance = (importance + delta).clamp(0.0, 1.0);
  }

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'] ?? '',
      typeIndex: _parseType(json['type']),
      importance: (json['importance'] as num?)?.toDouble() ?? 0.5,
      createdAt:
          json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'])
          : null,
      accessCount: json['access_count'] ?? 0,
      metadata: json['metadata'] != null
          ? Map<String, String>.from(json['metadata'])
          : null,
    );
  }

  static int _parseType(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    switch (value.toString().toLowerCase()) {
      case 'summary':
        return 0;
      case 'conclusion':
        return 1;
      case 'preference':
        return 2;
      case 'decision':
        return 3;
      case 'entity':
        return 4;
      default:
        return 0;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.name,
      'importance': importance,
      'created_at': createdAt.toIso8601String(),
      'last_accessed_at': lastAccessedAt?.toIso8601String(),
      'access_count': accessCount,
      'metadata': metadata,
    };
  }

  MemoryItem copyWith({
    String? content,
    MemoryType? type,
    double? importance,
    Map<String, String>? metadata,
  }) {
    return MemoryItem(
      id: id,
      content: content ?? this.content,
      typeIndex: type?.index ?? typeIndex,
      importance: importance ?? this.importance,
      createdAt: createdAt,
      lastAccessedAt: lastAccessedAt,
      accessCount: accessCount,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'MemoryItem(type: ${type.name}, content: $content, importance: $importance)';
  }
}

/// 对话记忆
@HiveType(typeId: 13)
class ConversationMemory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String conversationId;

  @HiveField(2)
  String summary;

  @HiveField(3)
  List<MemoryItem> memories;

  @HiveField(4)
  int originalMessageCount;

  @HiveField(5)
  int compressedAt;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  @HiveField(8)
  int version;

  ConversationMemory({
    required this.id,
    required this.conversationId,
    required this.summary,
    List<MemoryItem>? memories,
    this.originalMessageCount = 0,
    int? compressedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
  })  : memories = memories ?? [],
        compressedAt = compressedAt ?? 0,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 添加记忆项
  void addMemory(MemoryItem item) {
    memories.add(item);
    updatedAt = DateTime.now();
  }

  /// 获取按重要性排序的记忆
  List<MemoryItem> getTopMemories(int count) {
    final sorted = List<MemoryItem>.from(memories)
      ..sort((a, b) => b.importance.compareTo(a.importance));
    return sorted.take(count).toList();
  }

  /// 获取指定类型的记忆
  List<MemoryItem> getByType(MemoryType type) {
    return memories.where((m) => m.type == type).toList();
  }

  /// 清理低重要性的记忆
  void pruneMemories({double threshold = 0.2, int maxCount = 50}) {
    // 移除重要性低于阈值的
    memories.removeWhere((m) => m.importance < threshold);
    
    // 如果仍然超过最大数量，移除最不重要的
    if (memories.length > maxCount) {
      memories.sort((a, b) => b.importance.compareTo(a.importance));
      memories = memories.take(maxCount).toList();
    }
    
    updatedAt = DateTime.now();
  }

  /// 生成用于注入到 system prompt 的记忆文本
  String toPromptText() {
    final buffer = StringBuffer();
    
    // 摘要
    if (summary.isNotEmpty) {
      buffer.writeln('## 对话背景');
      buffer.writeln(summary);
      buffer.writeln();
    }

    // 关键结论
    final conclusions = getByType(MemoryType.conclusion);
    if (conclusions.isNotEmpty) {
      buffer.writeln('## 关键结论');
      for (final c in conclusions.take(5)) {
        buffer.writeln('- ${c.content}');
      }
      buffer.writeln();
    }

    // 用户偏好
    final preferences = getByType(MemoryType.preference);
    if (preferences.isNotEmpty) {
      buffer.writeln('## 用户偏好');
      for (final p in preferences.take(5)) {
        buffer.writeln('- ${p.content}');
      }
      buffer.writeln();
    }

    // 技术决策
    final decisions = getByType(MemoryType.decision);
    if (decisions.isNotEmpty) {
      buffer.writeln('## 技术决策');
      for (final d in decisions.take(5)) {
        buffer.writeln('- ${d.content}');
      }
      buffer.writeln();
    }

    // 重要实体
    final entities = getByType(MemoryType.entity);
    if (entities.isNotEmpty) {
      buffer.writeln('## 相关实体');
      for (final e in entities.take(10)) {
        buffer.writeln('- ${e.content}');
      }
    }

    return buffer.toString().trim();
  }

  /// 估算 token 数（简单估算：中文每字约 2 token，英文每词约 1 token）
  int estimateTokens() {
    final text = toPromptText();
    // 简单估算：平均每个字符 0.5 token
    return (text.length * 0.5).round();
  }

  factory ConversationMemory.fromJson(Map<String, dynamic> json) {
    return ConversationMemory(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: json['conversation_id'] ?? '',
      summary: json['summary'] ?? '',
      memories: json['memories'] != null
          ? (json['memories'] as List)
              .map((m) => MemoryItem.fromJson(m))
              .toList()
          : null,
      originalMessageCount: json['original_message_count'] ?? 0,
      compressedAt: json['compressed_at'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      version: json['version'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'summary': summary,
      'memories': memories.map((m) => m.toJson()).toList(),
      'original_message_count': originalMessageCount,
      'compressed_at': compressedAt,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'version': version,
    };
  }

  ConversationMemory copyWith({
    String? summary,
    List<MemoryItem>? memories,
    int? originalMessageCount,
    int? compressedAt,
  }) {
    return ConversationMemory(
      id: id,
      conversationId: conversationId,
      summary: summary ?? this.summary,
      memories: memories ?? this.memories,
      originalMessageCount: originalMessageCount ?? this.originalMessageCount,
      compressedAt: compressedAt ?? this.compressedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      version: version + 1,
    );
  }
}

/// 记忆统计
class MemoryStats {
  final int totalMemories;
  final int summaryCount;
  final int conclusionCount;
  final int preferenceCount;
  final int decisionCount;
  final int entityCount;
  final double averageImportance;
  final int estimatedTokens;

  MemoryStats({
    required this.totalMemories,
    required this.summaryCount,
    required this.conclusionCount,
    required this.preferenceCount,
    required this.decisionCount,
    required this.entityCount,
    required this.averageImportance,
    required this.estimatedTokens,
  });

  factory MemoryStats.fromMemory(ConversationMemory memory) {
    final memories = memory.memories;
    final avgImportance = memories.isNotEmpty
        ? memories.map((m) => m.importance).reduce((a, b) => a + b) /
            memories.length
        : 0.0;

    return MemoryStats(
      totalMemories: memories.length,
      summaryCount: memory.getByType(MemoryType.summary).length,
      conclusionCount: memory.getByType(MemoryType.conclusion).length,
      preferenceCount: memory.getByType(MemoryType.preference).length,
      decisionCount: memory.getByType(MemoryType.decision).length,
      entityCount: memory.getByType(MemoryType.entity).length,
      averageImportance: avgImportance,
      estimatedTokens: memory.estimateTokens(),
    );
  }
}
