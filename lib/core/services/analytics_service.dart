import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user_activity.dart';

/// 分析服务 - 记录和分析用户行为
class AnalyticsService {
  static const String _boxName = 'user_activities';
  static const int _retentionDays = 30; // 保留30天数据
  
  Box<UserActivity>? _box;
  
  /// 初始化
  Future<void> initialize() async {
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(UserActivityAdapter());
    }
    _box = await Hive.openBox<UserActivity>(_boxName);
    
    // 清理过期数据
    await _cleanupOldData();
  }
  
  /// 确保已初始化
  Box<UserActivity> get _activityBox {
    if (_box == null) {
      throw StateError('AnalyticsService 未初始化');
    }
    return _box!;
  }
  
  /// 记录活动
  Future<void> logActivity(
    ActivityType type, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final activity = UserActivity(
        id: const Uuid().v4(),
        activityTypeIndex: type.index,
        timestamp: DateTime.now(),
        metadata: metadata,
      );
      
      await _activityBox.put(activity.id, activity);
      debugPrint('AnalyticsService: 记录活动 ${type.name}');
    } catch (e) {
      debugPrint('AnalyticsService: 记录活动失败 - $e');
    }
  }
  
  /// 记录应用打开
  Future<void> logAppOpened() async {
    await logActivity(ActivityType.appOpened);
  }
  
  /// 记录日程创建
  Future<void> logScheduleCreated({
    String? scheduleId,
    bool isAllDay = false,
    int? reminderMinutes,
  }) async {
    await logActivity(
      ActivityType.scheduleCreated,
      metadata: {
        'scheduleId': scheduleId,
        'isAllDay': isAllDay,
        'reminderMinutes': reminderMinutes,
      },
    );
  }
  
  /// 记录日程完成
  Future<void> logScheduleCompleted({
    String? scheduleId,
    bool onTime = true,
  }) async {
    await logActivity(
      ActivityType.scheduleCompleted,
      metadata: {
        'scheduleId': scheduleId,
        'onTime': onTime,
      },
    );
  }
  
  /// 记录任务创建
  Future<void> logTaskCreated({
    String? taskId,
    String? priority,
    String? category,
  }) async {
    await logActivity(
      ActivityType.taskCreated,
      metadata: {
        'taskId': taskId,
        'priority': priority,
        'category': category,
      },
    );
  }
  
  /// 记录任务完成
  Future<void> logTaskCompleted({
    String? taskId,
    int? daysToComplete,
  }) async {
    await logActivity(
      ActivityType.taskCompleted,
      metadata: {
        'taskId': taskId,
        'daysToComplete': daysToComplete,
      },
    );
  }
  
  /// 记录聊天消息
  Future<void> logChatMessage({
    bool isUser = true,
    int? messageLength,
  }) async {
    await logActivity(
      ActivityType.chatMessage,
      metadata: {
        'isUser': isUser,
        'messageLength': messageLength,
      },
    );
  }
  
  /// 记录语音输入
  Future<void> logVoiceInput() async {
    await logActivity(ActivityType.voiceInput);
  }
  
  /// 记录语音输出
  Future<void> logVoiceOutput() async {
    await logActivity(ActivityType.voiceOutput);
  }
  
  /// 获取所有活动
  List<UserActivity> getAllActivities() {
    return _activityBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  /// 获取指定类型的活动
  List<UserActivity> getActivitiesByType(ActivityType type) {
    return _activityBox.values
        .where((a) => a.activityType == type)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  /// 获取指定日期范围的活动
  List<UserActivity> getActivitiesInRange(DateTime start, DateTime end) {
    return _activityBox.values
        .where((a) => a.timestamp.isAfter(start) && a.timestamp.isBefore(end))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  /// 分析用户习惯
  UserAnalytics analyze() {
    final activities = getAllActivities();
    
    // 活跃时段分析
    final activeHours = <int, int>{};
    final activeWeekdays = <int, int>{};
    
    for (final activity in activities) {
      activeHours[activity.hour] = (activeHours[activity.hour] ?? 0) + 1;
      activeWeekdays[activity.weekday] = (activeWeekdays[activity.weekday] ?? 0) + 1;
    }
    
    // 任务统计
    final taskCreated = getActivitiesByType(ActivityType.taskCreated);
    final taskCompleted = getActivitiesByType(ActivityType.taskCompleted);
    
    // 计算平均完成天数
    double avgCompletionDays = 0;
    if (taskCompleted.isNotEmpty) {
      final completionDays = taskCompleted
          .map((a) => a.metadata?['daysToComplete'] as int?)
          .whereType<int>();
      if (completionDays.isNotEmpty) {
        avgCompletionDays = completionDays.reduce((a, b) => a + b) / completionDays.length;
      }
    }
    
    // 统计最常用分类
    final categories = <String, int>{};
    for (final a in taskCreated) {
      final category = a.metadata?['category'] as String?;
      if (category != null) {
        categories[category] = (categories[category] ?? 0) + 1;
      }
    }
    String? mostUsedCategory;
    if (categories.isNotEmpty) {
      mostUsedCategory = categories.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }
    
    // 统计最常用优先级
    final priorities = <String, int>{};
    for (final a in taskCreated) {
      final priority = a.metadata?['priority'] as String?;
      if (priority != null) {
        priorities[priority] = (priorities[priority] ?? 0) + 1;
      }
    }
    String? mostUsedPriority;
    if (priorities.isNotEmpty) {
      mostUsedPriority = priorities.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }
    
    final taskStats = TaskCompletionStats(
      totalCreated: taskCreated.length,
      totalCompleted: taskCompleted.length,
      avgCompletionDays: avgCompletionDays,
      mostUsedCategory: mostUsedCategory,
      mostUsedPriority: mostUsedPriority,
    );
    
    // 日程统计
    final scheduleCreated = getActivitiesByType(ActivityType.scheduleCreated);
    final scheduleCompleted = getActivitiesByType(ActivityType.scheduleCompleted);
    
    // 计算每周平均日程数
    double avgPerWeek = 0;
    if (scheduleCreated.isNotEmpty) {
      final firstDate = scheduleCreated.last.timestamp;
      final weeks = DateTime.now().difference(firstDate).inDays / 7;
      if (weeks > 0) {
        avgPerWeek = scheduleCreated.length / weeks;
      }
    }
    
    // 统计最常用提醒时间
    final reminderTimes = <int, int>{};
    for (final a in scheduleCreated) {
      final minutes = a.metadata?['reminderMinutes'] as int?;
      if (minutes != null && minutes > 0) {
        reminderTimes[minutes] = (reminderTimes[minutes] ?? 0) + 1;
      }
    }
    String? preferredReminderTime;
    if (reminderTimes.isNotEmpty) {
      final preferredMinutes = reminderTimes.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      preferredReminderTime = _formatReminderMinutes(preferredMinutes);
    }
    
    final scheduleStats = ScheduleStats(
      totalCreated: scheduleCreated.length,
      totalCompleted: scheduleCompleted.length,
      avgPerWeek: avgPerWeek,
      preferredReminderTime: preferredReminderTime,
    );
    
    // 推断用户偏好
    int suggestedReminderHour = 8;
    if (activeHours.isNotEmpty) {
      // 找到用户最活跃的早晨时段
      final morningHours = [6, 7, 8, 9, 10];
      int maxActivity = 0;
      for (final h in morningHours) {
        if ((activeHours[h] ?? 0) > maxActivity) {
          maxActivity = activeHours[h] ?? 0;
          suggestedReminderHour = h;
        }
      }
    }
    
    int suggestedReminderMinutes = 15;
    if (reminderTimes.isNotEmpty) {
      suggestedReminderMinutes = reminderTimes.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }
    
    final inferredPreferences = UserPreferences(
      suggestedReminderHour: suggestedReminderHour,
      suggestedReminderMinutes: suggestedReminderMinutes,
      suggestedDefaultPriority: mostUsedPriority ?? 'medium',
    );
    
    return UserAnalytics(
      activeHours: activeHours,
      activeWeekdays: activeWeekdays,
      taskStats: taskStats,
      scheduleStats: scheduleStats,
      inferredPreferences: inferredPreferences,
    );
  }
  
  String _formatReminderMinutes(int minutes) {
    if (minutes < 60) {
      return '$minutes分钟前';
    } else if (minutes < 1440) {
      return '${minutes ~/ 60}小时前';
    } else {
      return '${minutes ~/ 1440}天前';
    }
  }
  
  /// 清理过期数据
  Future<void> _cleanupOldData() async {
    final cutoff = DateTime.now().subtract(Duration(days: _retentionDays));
    final keysToDelete = <String>[];
    
    for (final activity in _activityBox.values) {
      if (activity.timestamp.isBefore(cutoff)) {
        keysToDelete.add(activity.id);
      }
    }
    
    for (final key in keysToDelete) {
      await _activityBox.delete(key);
    }
    
    if (keysToDelete.isNotEmpty) {
      debugPrint('AnalyticsService: 清理了 ${keysToDelete.length} 条过期数据');
    }
  }
  
  /// 清空所有数据
  Future<void> clear() async {
    await _activityBox.clear();
  }
}

/// 分析服务 Provider
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

/// 用户分析结果 Provider
final userAnalyticsProvider = FutureProvider<UserAnalytics>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  await service.initialize();
  return service.analyze();
});
