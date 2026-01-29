import 'package:hive/hive.dart';

part 'task.g.dart';

/// 任务优先级
enum TaskPriority {
  low,
  medium,
  high,
  urgent,
}

/// 任务状态
enum TaskStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

/// 任务模型
@HiveType(typeId: 2)
class Task extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  int priorityIndex;

  @HiveField(4)
  int statusIndex;

  @HiveField(5)
  String? category;

  @HiveField(6)
  DateTime? dueDate;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime updatedAt;

  @HiveField(9)
  DateTime? completedAt;

  @HiveField(10)
  List<String>? tags;

  @HiveField(11)
  List<String>? subtasks;

  @HiveField(12)
  List<bool>? subtaskCompleted;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.priorityIndex = 1,
    this.statusIndex = 0,
    this.category,
    this.dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
    this.tags,
    this.subtasks,
    this.subtaskCompleted,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  TaskPriority get priority => TaskPriority.values[priorityIndex];
  set priority(TaskPriority value) => priorityIndex = value.index;

  TaskStatus get status => TaskStatus.values[statusIndex];
  set status(TaskStatus value) => statusIndex = value.index;

  bool get isCompleted => status == TaskStatus.completed;
  bool get isOverdue => dueDate != null && 
      dueDate!.isBefore(DateTime.now()) && 
      !isCompleted;

  /// 从 JSON 创建
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      description: json['description'],
      priorityIndex: _parsePriority(json['priorityIndex'] ?? json['priority']),
      statusIndex: _parseStatus(json['statusIndex'] ?? json['status']),
      category: json['category'],
      dueDate: json['dueDate'] != null || json['due_date'] != null
          ? _parseDateTime(json['dueDate'] ?? json['due_date'])
          : null,
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? _parseDateTime(json['createdAt'] ?? json['created_at'])
          : null,
      updatedAt: json['updatedAt'] != null || json['updated_at'] != null
          ? _parseDateTime(json['updatedAt'] ?? json['updated_at'])
          : null,
      completedAt: json['completedAt'] != null || json['completed_at'] != null
          ? _parseDateTime(json['completedAt'] ?? json['completed_at'])
          : null,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      subtasks: json['subtasks'] != null ? List<String>.from(json['subtasks']) : null,
      subtaskCompleted: json['subtaskCompleted'] != null 
          ? List<bool>.from(json['subtaskCompleted']) 
          : null,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.parse(value.toString());
  }

  static int _parsePriority(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    switch (value.toString().toLowerCase()) {
      case 'low': return 0;
      case 'medium': return 1;
      case 'high': return 2;
      case 'urgent': return 3;
      default: return 1;
    }
  }

  static int _parseStatus(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    switch (value.toString().toLowerCase()) {
      case 'pending': return 0;
      case 'inprogress':
      case 'in_progress': return 1;
      case 'completed': return 2;
      case 'cancelled': return 3;
      default: return 0;
    }
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': _priorityToString(),
      'status': _statusToString(),
      'category': category,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'tags': tags,
    };
  }

  String _priorityToString() {
    switch (priority) {
      case TaskPriority.low: return 'low';
      case TaskPriority.medium: return 'medium';
      case TaskPriority.high: return 'high';
      case TaskPriority.urgent: return 'urgent';
    }
  }

  String _statusToString() {
    switch (status) {
      case TaskStatus.pending: return 'pending';
      case TaskStatus.inProgress: return 'in_progress';
      case TaskStatus.completed: return 'completed';
      case TaskStatus.cancelled: return 'cancelled';
    }
  }

  /// 复制并修改
  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskPriority? priority,
    TaskStatus? status,
    String? category,
    DateTime? dueDate,
    DateTime? completedAt,
    List<String>? tags,
    List<String>? subtasks,
    List<bool>? subtaskCompleted,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priorityIndex: priority?.index ?? priorityIndex,
      statusIndex: status?.index ?? statusIndex,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      completedAt: completedAt ?? this.completedAt,
      tags: tags ?? this.tags,
      subtasks: subtasks ?? this.subtasks,
      subtaskCompleted: subtaskCompleted ?? this.subtaskCompleted,
    );
  }

  /// 获取优先级文本
  String get priorityText {
    switch (priority) {
      case TaskPriority.low:
        return '低';
      case TaskPriority.medium:
        return '中';
      case TaskPriority.high:
        return '高';
      case TaskPriority.urgent:
        return '紧急';
    }
  }

  /// 获取状态文本
  String get statusText {
    switch (status) {
      case TaskStatus.pending:
        return '待处理';
      case TaskStatus.inProgress:
        return '进行中';
      case TaskStatus.completed:
        return '已完成';
      case TaskStatus.cancelled:
        return '已取消';
    }
  }

  /// 格式化截止日期
  String? get formattedDueDate {
    if (dueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    
    final diff = due.difference(today).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff == -1) return '昨天';
    if (diff < 0) return '已过期 ${-diff} 天';
    if (diff <= 7) return '$diff 天后';
    return '${dueDate!.month}月${dueDate!.day}日';
  }
}
