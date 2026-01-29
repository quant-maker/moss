import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import 'notification_service.dart';
import 'schedule_service.dart';
import 'task_service.dart';

/// 后台任务名称
class BackgroundTasks {
  static const String dailyReminder = 'dailyReminder';
  static const String syncData = 'syncData';
  static const String cleanupOldData = 'cleanupOldData';
  static const String checkAlerts = 'checkAlerts';
}

/// 后台任务回调入口点
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('后台任务执行: $task');
    
    try {
      switch (task) {
        case BackgroundTasks.dailyReminder:
          await _handleDailyReminder();
          break;
        case BackgroundTasks.syncData:
          await _handleSyncData();
          break;
        case BackgroundTasks.cleanupOldData:
          await _handleCleanupOldData();
          break;
        case BackgroundTasks.checkAlerts:
          await _handleCheckAlerts();
          break;
        default:
          debugPrint('未知后台任务: $task');
      }
      return true;
    } catch (e) {
      debugPrint('后台任务执行失败: $e');
      return false;
    }
  });
}

/// 处理每日提醒
Future<void> _handleDailyReminder() async {
  try {
    // 初始化 Hive
    await Hive.initFlutter();
    
    // 注册适配器
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ScheduleAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(TaskAdapter());
    }
    
    final scheduleService = ScheduleService();
    final taskService = TaskService();
    await scheduleService.initialize();
    await taskService.initialize();
    
    // 获取今日日程和任务
    final todaySchedules = scheduleService.getToday();
    final pendingTasks = taskService.getPending();
    final dueTodayTasks = taskService.getDueToday();
    final overdueTasks = taskService.getOverdue();
    
    // 构建每日摘要
    final buffer = StringBuffer();
    
    // 日程部分
    if (todaySchedules.isNotEmpty) {
      buffer.writeln('${todaySchedules.length} 个日程');
      for (final s in todaySchedules.take(3)) {
        buffer.writeln('  ${s.formattedTime} ${s.title}');
      }
      if (todaySchedules.length > 3) {
        buffer.writeln('  ...');
      }
    }
    
    // 任务部分
    final taskCount = dueTodayTasks.length + overdueTasks.length;
    if (taskCount > 0) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('$taskCount 个待办任务');
      if (overdueTasks.isNotEmpty) {
        buffer.writeln('  ${overdueTasks.length} 个已过期');
      }
    }
    
    // 显示通知
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    String title = '早安！今日安排';
    String body;
    
    if (buffer.isEmpty) {
      body = '今天没有安排，享受自由的一天吧！';
    } else {
      body = buffer.toString().trim();
    }
    
    await notificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: 'daily_reminder',
    );
  } catch (e) {
    debugPrint('每日提醒失败: $e');
    // 显示简单提醒
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '早安',
      body: '查看今日的日程和任务安排',
      payload: 'daily_reminder',
    );
  }
}

/// 处理数据同步
Future<void> _handleSyncData() async {
  // TODO: 实现数据同步逻辑
  debugPrint('执行数据同步...');
}

/// 处理旧数据清理
Future<void> _handleCleanupOldData() async {
  // TODO: 实现旧数据清理逻辑
  debugPrint('执行旧数据清理...');
}

/// 处理预警检查
Future<void> _handleCheckAlerts() async {
  try {
    // 初始化 Hive
    await Hive.initFlutter();
    
    // 注册适配器
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ScheduleAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(TaskAdapter());
    }
    
    final scheduleService = ScheduleService();
    final taskService = TaskService();
    await scheduleService.initialize();
    await taskService.initialize();
    
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    // 检查过期任务
    final overdueTasks = taskService.getOverdue();
    if (overdueTasks.isNotEmpty) {
      await notificationService.showNotification(
        id: 'overdue_tasks'.hashCode,
        title: '任务过期提醒',
        body: '有 ${overdueTasks.length} 个任务已过截止日期',
        payload: 'alert:overdue_tasks',
      );
    }
    
    // 检查紧急任务今日到期
    final dueTodayTasks = taskService.getDueToday();
    final urgentTasks = dueTodayTasks.where(
      (t) => t.priority == TaskPriority.urgent && !t.isCompleted
    ).toList();
    
    for (final task in urgentTasks.take(2)) {
      await notificationService.showNotification(
        id: 'urgent_${task.id}'.hashCode,
        title: '紧急任务今日到期',
        body: task.title,
        payload: 'task:${task.id}',
      );
    }
    
    // 检查即将开始的日程 (15分钟内)
    final upcomingSchedules = scheduleService.getUpcomingInMinutes(15);
    for (final schedule in upcomingSchedules.take(2)) {
      final minutesUntil = schedule.startTime.difference(DateTime.now()).inMinutes;
      await notificationService.showNotification(
        id: 'upcoming_${schedule.id}'.hashCode,
        title: '日程即将开始',
        body: '${schedule.title} 将在 $minutesUntil 分钟后开始',
        payload: 'schedule:${schedule.id}',
      );
    }
    
    debugPrint('预警检查完成');
  } catch (e) {
    debugPrint('预警检查失败: $e');
  }
}

/// 后台任务服务
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  bool _isInitialized = false;

  /// 初始化后台服务
  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    
    _isInitialized = true;
    debugPrint('BackgroundService 初始化完成');
  }

  /// 注册每日提醒任务
  Future<void> registerDailyReminder({
    int hour = 8,
    int minute = 0,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    // 计算到下一个指定时间的延迟
    final now = DateTime.now();
    var nextRun = DateTime(now.year, now.month, now.day, hour, minute);
    if (nextRun.isBefore(now)) {
      nextRun = nextRun.add(const Duration(days: 1));
    }
    final delay = nextRun.difference(now);

    await Workmanager().registerPeriodicTask(
      'daily_reminder_task',
      BackgroundTasks.dailyReminder,
      frequency: const Duration(days: 1),
      initialDelay: delay,
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    debugPrint('已注册每日提醒任务，下次执行: $nextRun');
  }

  /// 注册数据同步任务
  Future<void> registerSyncTask({
    Duration frequency = const Duration(hours: 6),
  }) async {
    if (kIsWeb || !_isInitialized) return;

    await Workmanager().registerPeriodicTask(
      'sync_data_task',
      BackgroundTasks.syncData,
      frequency: frequency,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    debugPrint('已注册数据同步任务');
  }

  /// 注册清理任务
  Future<void> registerCleanupTask() async {
    if (kIsWeb || !_isInitialized) return;

    await Workmanager().registerPeriodicTask(
      'cleanup_old_data_task',
      BackgroundTasks.cleanupOldData,
      frequency: const Duration(days: 7),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: true,
        requiresDeviceIdle: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    debugPrint('已注册清理任务');
  }

  /// 注册预警检查任务 (每小时检查一次)
  Future<void> registerAlertCheckTask({
    Duration frequency = const Duration(hours: 1),
  }) async {
    if (kIsWeb || !_isInitialized) return;

    await Workmanager().registerPeriodicTask(
      'check_alerts_task',
      BackgroundTasks.checkAlerts,
      frequency: frequency,
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    debugPrint('已注册预警检查任务');
  }

  /// 取消所有后台任务
  Future<void> cancelAllTasks() async {
    if (kIsWeb || !_isInitialized) return;
    await Workmanager().cancelAll();
    debugPrint('已取消所有后台任务');
  }

  /// 取消指定任务
  Future<void> cancelTask(String taskName) async {
    if (kIsWeb || !_isInitialized) return;
    await Workmanager().cancelByUniqueName(taskName);
    debugPrint('已取消任务: $taskName');
  }

  /// 立即执行一次性任务
  Future<void> runOnce(String taskName) async {
    if (kIsWeb || !_isInitialized) return;

    await Workmanager().registerOneOffTask(
      '${taskName}_once_${DateTime.now().millisecondsSinceEpoch}',
      taskName,
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );
  }
}
