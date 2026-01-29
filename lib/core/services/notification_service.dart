import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/schedule.dart';
import '../models/task.dart';

/// 通知服务
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return; // Web 平台不支持本地通知
    }

    // 初始化时区
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // Android 设置
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS 设置
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _isInitialized = true;
    debugPrint('NotificationService 初始化完成');
  }

  /// 请求通知权限
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        // 请求通知权限 (Android 13+)
        final granted = await androidPlugin.requestNotificationsPermission();
        
        // 请求精确闹钟权限 (Android 12+)
        await androidPlugin.requestExactAlarmsPermission();
        
        return granted ?? false;
      }
    } else if (Platform.isIOS) {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    }
    
    return false;
  }

  /// 检查通知权限
  Future<bool> checkPermissions() async {
    if (kIsWeb) return false;
    
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        return await androidPlugin.areNotificationsEnabled() ?? false;
      }
    }
    
    return true; // iOS 假设已授权
  }

  /// 通知点击回调
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('通知点击: ${response.payload}');
    // TODO: 根据 payload 导航到对应页面
  }

  /// 立即显示通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized || kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'moss_general',
      '一般通知',
      channelDescription: 'Moss 智能管家通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// 调度日程通知
  Future<void> scheduleScheduleNotification(Schedule schedule) async {
    if (!_isInitialized || kIsWeb) return;
    if (schedule.startTime.isBefore(DateTime.now())) return;

    final scheduledTime = schedule.reminderMinutes > 0
        ? schedule.startTime.subtract(Duration(minutes: schedule.reminderMinutes))
        : schedule.startTime;

    if (scheduledTime.isBefore(DateTime.now())) return;

    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'moss_schedule',
      '日程提醒',
      channelDescription: '日程事项提醒通知',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      category: AndroidNotificationCategory.reminder,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      schedule.id.hashCode,
      '📅 日程提醒',
      schedule.title,
      tzScheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'schedule:${schedule.id}',
    );

    debugPrint('已调度日程通知: ${schedule.title} @ $tzScheduledTime');
  }

  /// 调度任务通知
  Future<void> scheduleTaskNotification(Task task) async {
    if (!_isInitialized || kIsWeb) return;
    if (task.dueDate == null) return;
    if (task.dueDate!.isBefore(DateTime.now())) return;

    // 在截止日期当天早上 9 点提醒
    final reminderTime = DateTime(
      task.dueDate!.year,
      task.dueDate!.month,
      task.dueDate!.day,
      9,
      0,
    );

    if (reminderTime.isBefore(DateTime.now())) return;

    final tzReminderTime = tz.TZDateTime.from(reminderTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'moss_task',
      '任务提醒',
      channelDescription: '待办任务提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      category: AndroidNotificationCategory.reminder,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      task.id.hashCode,
      '✅ 任务提醒',
      '${task.title} 今日到期',
      tzReminderTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task:${task.id}',
    );

    debugPrint('已调度任务通知: ${task.title} @ $tzReminderTime');
  }

  /// 取消日程通知
  Future<void> cancelScheduleNotification(String scheduleId) async {
    if (!_isInitialized || kIsWeb) return;
    await _notifications.cancel(scheduleId.hashCode);
  }

  /// 取消任务通知
  Future<void> cancelTaskNotification(String taskId) async {
    if (!_isInitialized || kIsWeb) return;
    await _notifications.cancel(taskId.hashCode);
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    if (!_isInitialized || kIsWeb) return;
    await _notifications.cancelAll();
  }

  /// 获取待处理的通知
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized || kIsWeb) return [];
    return await _notifications.pendingNotificationRequests();
  }
}
