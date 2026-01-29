import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import 'schedule_service.dart';
import 'task_service.dart';
import 'notification_service.dart';

/// 预警类型
enum AlertType {
  /// 过期任务
  overdueTask,
  /// 紧急任务今日到期
  urgentTaskDueToday,
  /// 日程即将开始
  scheduleStartingSoon,
  /// 明日重要日程
  importantScheduleTomorrow,
  /// 过期日程未处理
  overdueSchedule,
  /// 高优先级任务积压
  taskBacklog,
}

/// 预警项
class AlertItem {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final Map<String, dynamic>? data;
  final String? relatedId;
  
  AlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    DateTime? createdAt,
    this.data,
    this.relatedId,
  }) : createdAt = createdAt ?? DateTime.now();
  
  /// 获取预警图标名称
  String get iconName {
    switch (type) {
      case AlertType.overdueTask:
        return 'warning';
      case AlertType.urgentTaskDueToday:
        return 'priority_high';
      case AlertType.scheduleStartingSoon:
        return 'schedule';
      case AlertType.importantScheduleTomorrow:
        return 'event';
      case AlertType.overdueSchedule:
        return 'event_busy';
      case AlertType.taskBacklog:
        return 'assignment_late';
    }
  }
  
  /// 预警优先级 (数字越小优先级越高)
  int get priority {
    switch (type) {
      case AlertType.scheduleStartingSoon:
        return 1;
      case AlertType.urgentTaskDueToday:
        return 2;
      case AlertType.overdueTask:
        return 3;
      case AlertType.overdueSchedule:
        return 4;
      case AlertType.importantScheduleTomorrow:
        return 5;
      case AlertType.taskBacklog:
        return 6;
    }
  }
}

/// 预警服务状态
class AlertServiceState {
  final List<AlertItem> alerts;
  final bool isChecking;
  final DateTime? lastCheckTime;
  
  AlertServiceState({
    this.alerts = const [],
    this.isChecking = false,
    this.lastCheckTime,
  });
  
  AlertServiceState copyWith({
    List<AlertItem>? alerts,
    bool? isChecking,
    DateTime? lastCheckTime,
  }) {
    return AlertServiceState(
      alerts: alerts ?? this.alerts,
      isChecking: isChecking ?? this.isChecking,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
    );
  }
  
  /// 是否有预警
  bool get hasAlerts => alerts.isNotEmpty;
  
  /// 高优先级预警数量
  int get highPriorityCount => alerts.where((a) => a.priority <= 3).length;
}

/// 预警服务
class AlertService {
  final ScheduleService _scheduleService;
  final TaskService _taskService;
  final NotificationService _notificationService = NotificationService();
  
  AlertService(this._scheduleService, this._taskService);
  
  /// 检查所有预警
  Future<List<AlertItem>> checkAlerts() async {
    final alerts = <AlertItem>[];
    
    try {
      await _scheduleService.initialize();
      await _taskService.initialize();
      
      // 1. 检查过期任务
      alerts.addAll(await _checkOverdueTasks());
      
      // 2. 检查紧急任务今日到期
      alerts.addAll(await _checkUrgentTasksDueToday());
      
      // 3. 检查即将开始的日程
      alerts.addAll(await _checkUpcomingSchedules());
      
      // 4. 检查明日重要日程
      alerts.addAll(await _checkImportantSchedulesTomorrow());
      
      // 5. 检查过期日程
      alerts.addAll(await _checkOverdueSchedules());
      
      // 6. 检查任务积压
      alerts.addAll(await _checkTaskBacklog());
      
      // 按优先级排序
      alerts.sort((a, b) => a.priority.compareTo(b.priority));
      
    } catch (e) {
      debugPrint('AlertService: 检查预警失败 - $e');
    }
    
    return alerts;
  }
  
  /// 检查过期任务
  Future<List<AlertItem>> _checkOverdueTasks() async {
    final overdueTasks = _taskService.getOverdue();
    
    if (overdueTasks.isEmpty) return [];
    
    if (overdueTasks.length == 1) {
      final task = overdueTasks.first;
      return [
        AlertItem(
          id: 'overdue_task_${task.id}',
          type: AlertType.overdueTask,
          title: '任务已过期',
          message: '${task.title} 已过截止日期',
          relatedId: task.id,
          data: {'task': task.toJson()},
        ),
      ];
    } else {
      return [
        AlertItem(
          id: 'overdue_tasks_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.overdueTask,
          title: '有 ${overdueTasks.length} 个任务已过期',
          message: overdueTasks.take(3).map((t) => t.title).join('、') +
              (overdueTasks.length > 3 ? '...' : ''),
          data: {'count': overdueTasks.length},
        ),
      ];
    }
  }
  
  /// 检查紧急任务今日到期
  Future<List<AlertItem>> _checkUrgentTasksDueToday() async {
    final alerts = <AlertItem>[];
    final dueTodayTasks = _taskService.getDueToday();
    final urgentTasks = dueTodayTasks.where(
      (t) => t.priority == TaskPriority.urgent && !t.isCompleted
    ).toList();
    
    for (final task in urgentTasks) {
      alerts.add(AlertItem(
        id: 'urgent_today_${task.id}',
        type: AlertType.urgentTaskDueToday,
        title: '紧急任务今日到期',
        message: task.title,
        relatedId: task.id,
        data: {'task': task.toJson()},
      ));
    }
    
    return alerts;
  }
  
  /// 检查即将开始的日程 (15分钟内)
  Future<List<AlertItem>> _checkUpcomingSchedules() async {
    final alerts = <AlertItem>[];
    final upcomingSchedules = _scheduleService.getUpcomingInMinutes(15);
    
    for (final schedule in upcomingSchedules) {
      final minutesUntil = schedule.startTime.difference(DateTime.now()).inMinutes;
      alerts.add(AlertItem(
        id: 'starting_soon_${schedule.id}',
        type: AlertType.scheduleStartingSoon,
        title: '日程即将开始',
        message: '${schedule.title} 将在 $minutesUntil 分钟后开始',
        relatedId: schedule.id,
        data: {'schedule': schedule.toJson()},
      ));
    }
    
    return alerts;
  }
  
  /// 检查明日重要日程
  Future<List<AlertItem>> _checkImportantSchedulesTomorrow() async {
    final alerts = <AlertItem>[];
    final tomorrowSchedules = _scheduleService.getTomorrow();
    
    // 有提醒设置的视为重要
    final importantSchedules = tomorrowSchedules.where(
      (s) => s.reminderTime != ReminderTime.none && !s.isCompleted
    ).toList();
    
    if (importantSchedules.isNotEmpty) {
      if (importantSchedules.length == 1) {
        final schedule = importantSchedules.first;
        alerts.add(AlertItem(
          id: 'tomorrow_important_${schedule.id}',
          type: AlertType.importantScheduleTomorrow,
          title: '明天有重要日程',
          message: schedule.title,
          relatedId: schedule.id,
          data: {'schedule': schedule.toJson()},
        ));
      } else {
        alerts.add(AlertItem(
          id: 'tomorrow_important_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.importantScheduleTomorrow,
          title: '明天有 ${importantSchedules.length} 个重要日程',
          message: importantSchedules.take(3).map((s) => s.title).join('、') +
              (importantSchedules.length > 3 ? '...' : ''),
          data: {'count': importantSchedules.length},
        ));
      }
    }
    
    return alerts;
  }
  
  /// 检查过期日程
  Future<List<AlertItem>> _checkOverdueSchedules() async {
    final overdueSchedules = _scheduleService.getOverdue();
    
    if (overdueSchedules.isEmpty) return [];
    
    if (overdueSchedules.length == 1) {
      final schedule = overdueSchedules.first;
      return [
        AlertItem(
          id: 'overdue_schedule_${schedule.id}',
          type: AlertType.overdueSchedule,
          title: '日程已过期',
          message: schedule.title,
          relatedId: schedule.id,
          data: {'schedule': schedule.toJson()},
        ),
      ];
    } else {
      return [
        AlertItem(
          id: 'overdue_schedules_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.overdueSchedule,
          title: '有 ${overdueSchedules.length} 个日程已过期',
          message: overdueSchedules.take(3).map((s) => s.title).join('、') +
              (overdueSchedules.length > 3 ? '...' : ''),
          data: {'count': overdueSchedules.length},
        ),
      ];
    }
  }
  
  /// 检查任务积压 (高优先级任务超过5个未完成)
  Future<List<AlertItem>> _checkTaskBacklog() async {
    final pendingTasks = _taskService.getPending();
    final highPriorityTasks = pendingTasks.where(
      (t) => t.priority == TaskPriority.high || t.priority == TaskPriority.urgent
    ).toList();
    
    if (highPriorityTasks.length >= 5) {
      return [
        AlertItem(
          id: 'task_backlog_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.taskBacklog,
          title: '高优先级任务积压',
          message: '有 ${highPriorityTasks.length} 个高优先级任务待处理',
          data: {'count': highPriorityTasks.length},
        ),
      ];
    }
    
    return [];
  }
  
  /// 发送预警通知
  Future<void> sendAlertNotifications(List<AlertItem> alerts) async {
    if (alerts.isEmpty) return;
    
    await _notificationService.initialize();
    
    // 只发送高优先级预警通知
    final highPriorityAlerts = alerts.where((a) => a.priority <= 3).toList();
    
    for (final alert in highPriorityAlerts.take(3)) {
      await _notificationService.showNotification(
        id: alert.id.hashCode,
        title: alert.title,
        body: alert.message,
        payload: 'alert:${alert.id}',
      );
    }
  }
}

/// 预警服务 Notifier
class AlertServiceNotifier extends StateNotifier<AlertServiceState> {
  final AlertService _service;
  
  AlertServiceNotifier(this._service) : super(AlertServiceState());
  
  /// 检查预警
  Future<void> checkAlerts({bool sendNotifications = false}) async {
    state = state.copyWith(isChecking: true);
    
    try {
      final alerts = await _service.checkAlerts();
      
      if (sendNotifications) {
        await _service.sendAlertNotifications(alerts);
      }
      
      state = state.copyWith(
        alerts: alerts,
        isChecking: false,
        lastCheckTime: DateTime.now(),
      );
    } catch (e) {
      debugPrint('AlertServiceNotifier: 检查失败 - $e');
      state = state.copyWith(isChecking: false);
    }
  }
  
  /// 清除预警
  void clearAlerts() {
    state = state.copyWith(alerts: []);
  }
  
  /// 移除单个预警
  void dismissAlert(String alertId) {
    state = state.copyWith(
      alerts: state.alerts.where((a) => a.id != alertId).toList(),
    );
  }
}

/// 预警服务 Provider
final alertServiceProvider = StateNotifierProvider<AlertServiceNotifier, AlertServiceState>((ref) {
  final scheduleService = ref.watch(scheduleServiceProvider);
  final taskService = ref.watch(taskServiceProvider);
  final service = AlertService(scheduleService, taskService);
  return AlertServiceNotifier(service);
});
