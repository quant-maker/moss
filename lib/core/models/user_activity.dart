import 'package:hive_flutter/hive_flutter.dart';

part 'user_activity.g.dart';

/// 用户活动类型
enum ActivityType {
  /// 应用打开
  appOpened,
  /// 创建日程
  scheduleCreated,
  /// 完成日程
  scheduleCompleted,
  /// 创建任务
  taskCreated,
  /// 完成任务
  taskCompleted,
  /// 发送聊天消息
  chatMessage,
  /// 使用语音输入
  voiceInput,
  /// 使用语音播放
  voiceOutput,
}

/// 用户活动记录
@HiveType(typeId: 10)
class UserActivity extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final int activityTypeIndex;
  
  @HiveField(2)
  final DateTime timestamp;
  
  @HiveField(3)
  final Map<String, dynamic>? metadata;
  
  UserActivity({
    required this.id,
    required this.activityTypeIndex,
    required this.timestamp,
    this.metadata,
  });
  
  /// 活动类型
  ActivityType get activityType => ActivityType.values[activityTypeIndex];
  
  /// 小时 (0-23)
  int get hour => timestamp.hour;
  
  /// 星期几 (1-7, 1=周一)
  int get weekday => timestamp.weekday;
  
  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityType': activityType.name,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  /// 从 JSON 创建
  factory UserActivity.fromJson(Map<String, dynamic> json) {
    return UserActivity(
      id: json['id'] as String,
      activityTypeIndex: ActivityType.values
          .firstWhere((e) => e.name == json['activityType'])
          .index,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// 用户习惯分析结果
class UserAnalytics {
  /// 活跃时段分布 (小时 -> 活动次数)
  final Map<int, int> activeHours;
  
  /// 活跃星期分布 (星期 -> 活动次数)
  final Map<int, int> activeWeekdays;
  
  /// 任务完成统计
  final TaskCompletionStats taskStats;
  
  /// 日程统计
  final ScheduleStats scheduleStats;
  
  /// 偏好设置推断
  final UserPreferences inferredPreferences;
  
  UserAnalytics({
    required this.activeHours,
    required this.activeWeekdays,
    required this.taskStats,
    required this.scheduleStats,
    required this.inferredPreferences,
  });
  
  /// 获取最活跃的小时
  int? get peakHour {
    if (activeHours.isEmpty) return null;
    return activeHours.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
  
  /// 获取最活跃的星期
  int? get peakWeekday {
    if (activeWeekdays.isEmpty) return null;
    return activeWeekdays.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
  
  /// 是否是工作日活跃用户
  bool get isWeekdayUser {
    final weekdayTotal = [1, 2, 3, 4, 5]
        .map((d) => activeWeekdays[d] ?? 0)
        .reduce((a, b) => a + b);
    final weekendTotal = [6, 7]
        .map((d) => activeWeekdays[d] ?? 0)
        .reduce((a, b) => a + b);
    return weekdayTotal > weekendTotal * 2;
  }
  
  /// 是否是早起用户 (6-9点活跃)
  bool get isEarlyBird {
    final earlyTotal = [6, 7, 8, 9]
        .map((h) => activeHours[h] ?? 0)
        .reduce((a, b) => a + b);
    final total = activeHours.values.fold(0, (a, b) => a + b);
    return total > 0 && earlyTotal / total > 0.3;
  }
  
  /// 是否是夜猫子 (22-2点活跃)
  bool get isNightOwl {
    final nightTotal = [22, 23, 0, 1, 2]
        .map((h) => activeHours[h] ?? 0)
        .reduce((a, b) => a + b);
    final total = activeHours.values.fold(0, (a, b) => a + b);
    return total > 0 && nightTotal / total > 0.3;
  }
}

/// 任务完成统计
class TaskCompletionStats {
  /// 总创建数
  final int totalCreated;
  /// 总完成数
  final int totalCompleted;
  /// 平均完成天数
  final double avgCompletionDays;
  /// 最常用分类
  final String? mostUsedCategory;
  /// 最常用优先级
  final String? mostUsedPriority;
  
  TaskCompletionStats({
    this.totalCreated = 0,
    this.totalCompleted = 0,
    this.avgCompletionDays = 0,
    this.mostUsedCategory,
    this.mostUsedPriority,
  });
  
  /// 完成率
  double get completionRate {
    if (totalCreated == 0) return 0;
    return totalCompleted / totalCreated;
  }
}

/// 日程统计
class ScheduleStats {
  /// 总创建数
  final int totalCreated;
  /// 总完成数
  final int totalCompleted;
  /// 每周平均日程数
  final double avgPerWeek;
  /// 最常用提醒时间
  final String? preferredReminderTime;
  
  ScheduleStats({
    this.totalCreated = 0,
    this.totalCompleted = 0,
    this.avgPerWeek = 0,
    this.preferredReminderTime,
  });
}

/// 推断的用户偏好
class UserPreferences {
  /// 建议的每日提醒时间
  final int suggestedReminderHour;
  /// 建议的提前提醒分钟数
  final int suggestedReminderMinutes;
  /// 建议的默认任务优先级
  final String suggestedDefaultPriority;
  
  UserPreferences({
    this.suggestedReminderHour = 8,
    this.suggestedReminderMinutes = 15,
    this.suggestedDefaultPriority = 'medium',
  });
}
