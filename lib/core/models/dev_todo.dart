import 'package:hive/hive.dart';

part 'dev_todo.g.dart';

/// 开发任务状态（参考 opencode 的 Todo 机制）
enum DevTodoStatus {
  /// 待处理
  pending,

  /// 进行中（同一时间只能有一个）
  inProgress,

  /// 已完成
  completed,

  /// 已取消
  cancelled,
}

/// 开发任务优先级
enum DevTodoPriority {
  low,
  medium,
  high,
}

/// 开发任务模型
/// 用于跟踪 AI 助手执行复杂多步骤任务的进度
@HiveType(typeId: 11)
class DevTodo extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String content;

  @HiveField(2)
  int statusIndex;

  @HiveField(3)
  int priorityIndex;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime? updatedAt;

  @HiveField(6)
  DateTime? completedAt;

  @HiveField(7)
  String? sessionId;

  @HiveField(8)
  String? parentId;

  @HiveField(9)
  int orderIndex;

  DevTodo({
    required this.id,
    required this.content,
    this.statusIndex = 0,
    this.priorityIndex = 1,
    DateTime? createdAt,
    this.updatedAt,
    this.completedAt,
    this.sessionId,
    this.parentId,
    this.orderIndex = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 状态
  DevTodoStatus get status => DevTodoStatus.values[statusIndex];
  set status(DevTodoStatus value) {
    statusIndex = value.index;
    updatedAt = DateTime.now();
    if (value == DevTodoStatus.completed) {
      completedAt = DateTime.now();
    }
  }

  /// 优先级
  DevTodoPriority get priority => DevTodoPriority.values[priorityIndex];
  set priority(DevTodoPriority value) {
    priorityIndex = value.index;
    updatedAt = DateTime.now();
  }

  /// 是否为待处理
  bool get isPending => status == DevTodoStatus.pending;

  /// 是否进行中
  bool get isInProgress => status == DevTodoStatus.inProgress;

  /// 是否已完成
  bool get isCompleted => status == DevTodoStatus.completed;

  /// 是否已取消
  bool get isCancelled => status == DevTodoStatus.cancelled;

  /// 是否为活跃状态（待处理或进行中）
  bool get isActive => isPending || isInProgress;

  /// 从 JSON 创建
  factory DevTodo.fromJson(Map<String, dynamic> json) {
    return DevTodo(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'] ?? '',
      statusIndex: _parseStatus(json['status']),
      priorityIndex: _parsePriority(json['priority']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      sessionId: json['session_id'],
      parentId: json['parent_id'],
      orderIndex: json['order_index'] ?? 0,
    );
  }

  static int _parseStatus(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    switch (value.toString().toLowerCase()) {
      case 'pending':
        return 0;
      case 'in_progress':
      case 'inprogress':
        return 1;
      case 'completed':
        return 2;
      case 'cancelled':
        return 3;
      default:
        return 0;
    }
  }

  static int _parsePriority(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    switch (value.toString().toLowerCase()) {
      case 'low':
        return 0;
      case 'medium':
        return 1;
      case 'high':
        return 2;
      default:
        return 1;
    }
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'status': _statusToString(),
      'priority': _priorityToString(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'session_id': sessionId,
      'parent_id': parentId,
      'order_index': orderIndex,
    };
  }

  String _statusToString() {
    switch (status) {
      case DevTodoStatus.pending:
        return 'pending';
      case DevTodoStatus.inProgress:
        return 'in_progress';
      case DevTodoStatus.completed:
        return 'completed';
      case DevTodoStatus.cancelled:
        return 'cancelled';
    }
  }

  String _priorityToString() {
    switch (priority) {
      case DevTodoPriority.low:
        return 'low';
      case DevTodoPriority.medium:
        return 'medium';
      case DevTodoPriority.high:
        return 'high';
    }
  }

  /// 复制并修改
  DevTodo copyWith({
    String? id,
    String? content,
    DevTodoStatus? status,
    DevTodoPriority? priority,
    String? sessionId,
    String? parentId,
    int? orderIndex,
  }) {
    return DevTodo(
      id: id ?? this.id,
      content: content ?? this.content,
      statusIndex: status?.index ?? statusIndex,
      priorityIndex: priority?.index ?? priorityIndex,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      completedAt: status == DevTodoStatus.completed
          ? DateTime.now()
          : completedAt,
      sessionId: sessionId ?? this.sessionId,
      parentId: parentId ?? this.parentId,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  /// 获取状态文本
  String get statusText {
    switch (status) {
      case DevTodoStatus.pending:
        return '待处理';
      case DevTodoStatus.inProgress:
        return '进行中';
      case DevTodoStatus.completed:
        return '已完成';
      case DevTodoStatus.cancelled:
        return '已取消';
    }
  }

  /// 获取状态图标
  String get statusIcon {
    switch (status) {
      case DevTodoStatus.pending:
        return '○';
      case DevTodoStatus.inProgress:
        return '◐';
      case DevTodoStatus.completed:
        return '●';
      case DevTodoStatus.cancelled:
        return '✕';
    }
  }

  /// 获取优先级文本
  String get priorityText {
    switch (priority) {
      case DevTodoPriority.low:
        return '低';
      case DevTodoPriority.medium:
        return '中';
      case DevTodoPriority.high:
        return '高';
    }
  }

  @override
  String toString() {
    return '${statusIcon} [${priorityText}] $content';
  }
}

/// Todo 列表统计
class DevTodoStats {
  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int cancelled;

  DevTodoStats({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.cancelled,
  });

  /// 活跃任务数（待处理 + 进行中）
  int get active => pending + inProgress;

  /// 完成率
  double get completionRate => total > 0 ? completed / total : 0.0;

  /// 是否全部完成
  bool get isAllCompleted => pending == 0 && inProgress == 0;

  factory DevTodoStats.fromList(List<DevTodo> todos) {
    return DevTodoStats(
      total: todos.length,
      pending: todos.where((t) => t.isPending).length,
      inProgress: todos.where((t) => t.isInProgress).length,
      completed: todos.where((t) => t.isCompleted).length,
      cancelled: todos.where((t) => t.isCancelled).length,
    );
  }

  @override
  String toString() {
    return 'DevTodoStats(total: $total, pending: $pending, inProgress: $inProgress, completed: $completed)';
  }
}
