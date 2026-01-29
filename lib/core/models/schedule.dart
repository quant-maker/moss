import 'package:hive/hive.dart';

part 'schedule.g.dart';

/// 日程重复类型
enum RepeatType {
  none,      // 不重复
  daily,     // 每天
  weekly,    // 每周
  monthly,   // 每月
  yearly,    // 每年
}

/// 日程提醒时间
enum ReminderTime {
  none,           // 不提醒
  atTime,         // 准时
  minutes5,       // 5分钟前
  minutes15,      // 15分钟前
  minutes30,      // 30分钟前
  hour1,          // 1小时前
  day1,           // 1天前
}

/// 日程模型
@HiveType(typeId: 1)
class Schedule extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  DateTime startTime;

  @HiveField(4)
  DateTime? endTime;

  @HiveField(5)
  bool isAllDay;

  @HiveField(6)
  String? location;

  @HiveField(7)
  int repeatTypeIndex;

  @HiveField(8)
  int reminderTimeIndex;

  @HiveField(9)
  bool isCompleted;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  DateTime updatedAt;

  @HiveField(12)
  String? color;

  Schedule({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    this.isAllDay = false,
    this.location,
    this.repeatTypeIndex = 0,
    this.reminderTimeIndex = 0,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.color,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  RepeatType get repeatType => RepeatType.values[repeatTypeIndex];
  set repeatType(RepeatType value) => repeatTypeIndex = value.index;

  ReminderTime get reminderTime => ReminderTime.values[reminderTimeIndex];
  set reminderTime(ReminderTime value) => reminderTimeIndex = value.index;

  /// 从 JSON 创建
  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      description: json['description'],
      startTime: _parseDateTime(json['startTime'] ?? json['start_time']),
      endTime: json['endTime'] != null || json['end_time'] != null
          ? _parseDateTime(json['endTime'] ?? json['end_time'])
          : null,
      isAllDay: json['isAllDay'] ?? json['is_all_day'] ?? false,
      location: json['location'],
      repeatTypeIndex: json['repeatTypeIndex'] ?? json['repeat_type'] ?? 0,
      reminderTimeIndex: json['reminderTimeIndex'] ?? json['reminder'] ?? 0,
      isCompleted: json['isCompleted'] ?? json['is_completed'] ?? false,
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? _parseDateTime(json['createdAt'] ?? json['created_at'])
          : null,
      updatedAt: json['updatedAt'] != null || json['updated_at'] != null
          ? _parseDateTime(json['updatedAt'] ?? json['updated_at'])
          : null,
      color: json['color'],
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.parse(value.toString());
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'is_all_day': isAllDay,
      'location': location,
      'repeat_type': repeatTypeIndex,
      'reminder': reminderMinutes,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'color': color,
    };
  }

  /// 获取提醒分钟数
  int get reminderMinutes {
    switch (reminderTime) {
      case ReminderTime.none:
        return 0;
      case ReminderTime.atTime:
        return 0;
      case ReminderTime.minutes5:
        return 5;
      case ReminderTime.minutes15:
        return 15;
      case ReminderTime.minutes30:
        return 30;
      case ReminderTime.hour1:
        return 60;
      case ReminderTime.day1:
        return 1440;
    }
  }

  /// 复制并修改
  Schedule copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? location,
    RepeatType? repeatType,
    ReminderTime? reminderTime,
    bool? isCompleted,
    String? color,
  }) {
    return Schedule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      repeatTypeIndex: repeatType?.index ?? repeatTypeIndex,
      reminderTimeIndex: reminderTime?.index ?? reminderTimeIndex,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      color: color ?? this.color,
    );
  }

  /// 格式化时间显示
  String get formattedTime {
    if (isAllDay) {
      return '全天';
    }
    final hour = startTime.hour.toString().padLeft(2, '0');
    final minute = startTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 格式化日期显示
  String get formattedDate {
    return '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
  }

  /// 获取重复类型文本
  String get repeatTypeText {
    switch (repeatType) {
      case RepeatType.none:
        return '不重复';
      case RepeatType.daily:
        return '每天';
      case RepeatType.weekly:
        return '每周';
      case RepeatType.monthly:
        return '每月';
      case RepeatType.yearly:
        return '每年';
    }
  }

  /// 获取提醒时间文本
  String get reminderTimeText {
    switch (reminderTime) {
      case ReminderTime.none:
        return '不提醒';
      case ReminderTime.atTime:
        return '准时提醒';
      case ReminderTime.minutes5:
        return '5分钟前';
      case ReminderTime.minutes15:
        return '15分钟前';
      case ReminderTime.minutes30:
        return '30分钟前';
      case ReminderTime.hour1:
        return '1小时前';
      case ReminderTime.day1:
        return '1天前';
    }
  }
}
