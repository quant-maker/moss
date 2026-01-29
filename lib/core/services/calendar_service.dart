import 'dart:io';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import '../models/schedule.dart';

/// 系统日历集成服务
class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final DeviceCalendarPlugin _deviceCalendar = DeviceCalendarPlugin();
  
  bool _hasPermission = false;
  List<Calendar>? _calendars;

  /// 检查并请求日历权限
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    
    try {
      var permissionsGranted = await _deviceCalendar.hasPermissions();
      if (permissionsGranted.isSuccess && !(permissionsGranted.data ?? false)) {
        permissionsGranted = await _deviceCalendar.requestPermissions();
      }
      
      _hasPermission = permissionsGranted.isSuccess && (permissionsGranted.data ?? false);
      return _hasPermission;
    } catch (e) {
      debugPrint('请求日历权限失败: $e');
      return false;
    }
  }

  /// 获取可用日历列表
  Future<List<Calendar>> getCalendars() async {
    if (!_hasPermission) {
      await requestPermissions();
    }
    
    if (!_hasPermission) return [];

    try {
      final result = await _deviceCalendar.retrieveCalendars();
      if (result.isSuccess && result.data != null) {
        _calendars = result.data!
            .where((c) => !c.isReadOnly!)
            .toList();
        return _calendars!;
      }
    } catch (e) {
      debugPrint('获取日历列表失败: $e');
    }
    
    return [];
  }

  /// 获取默认日历
  Future<Calendar?> getDefaultCalendar() async {
    final calendars = await getCalendars();
    if (calendars.isEmpty) return null;
    
    // 优先选择主日历
    return calendars.firstWhere(
      (c) => c.name?.toLowerCase().contains('calendar') == true ||
             c.name?.contains('日历') == true,
      orElse: () => calendars.first,
    );
  }

  /// 将日程同步到系统日历
  Future<String?> syncScheduleToCalendar(
    Schedule schedule, {
    String? calendarId,
  }) async {
    if (kIsWeb) return null;
    
    if (!_hasPermission) {
      final granted = await requestPermissions();
      if (!granted) return null;
    }

    try {
      // 获取日历
      Calendar? calendar;
      if (calendarId != null) {
        final calendars = await getCalendars();
        calendar = calendars.where((c) => c.id == calendarId).firstOrNull;
      }
      calendar ??= await getDefaultCalendar();
      
      if (calendar == null) {
        debugPrint('未找到可用日历');
        return null;
      }

      // 创建事件
      final event = Event(calendar.id);
      event.title = schedule.title;
      event.description = schedule.description;
      event.start = TZDateTime.from(schedule.startTime, local);
      event.end = TZDateTime.from(
        schedule.endTime ?? schedule.startTime.add(const Duration(hours: 1)),
        local,
      );
      event.allDay = schedule.isAllDay;
      
      if (schedule.location != null) {
        event.location = schedule.location;
      }

      // 添加提醒
      if (schedule.reminderMinutes > 0) {
        event.reminders = [
          Reminder(minutes: schedule.reminderMinutes),
        ];
      }

      // 保存事件
      final result = await _deviceCalendar.createOrUpdateEvent(event);
      
      if (result?.isSuccess == true && result?.data != null) {
        debugPrint('已同步日程到系统日历: ${schedule.title}');
        return result!.data;
      }
    } catch (e) {
      debugPrint('同步日程到系统日历失败: $e');
    }
    
    return null;
  }

  /// 从系统日历删除事件
  Future<bool> deleteFromCalendar(String calendarId, String eventId) async {
    if (kIsWeb) return false;
    
    try {
      final result = await _deviceCalendar.deleteEvent(calendarId, eventId);
      return result.isSuccess;
    } catch (e) {
      debugPrint('从系统日历删除事件失败: $e');
      return false;
    }
  }

  /// 获取系统日历中的事件
  Future<List<Event>> getEvents({
    required DateTime start,
    required DateTime end,
    String? calendarId,
  }) async {
    if (kIsWeb) return [];
    
    if (!_hasPermission) {
      final granted = await requestPermissions();
      if (!granted) return [];
    }

    try {
      List<Calendar> calendarsToSearch;
      if (calendarId != null) {
        final calendars = await getCalendars();
        calendarsToSearch = calendars.where((c) => c.id == calendarId).toList();
      } else {
        calendarsToSearch = await getCalendars();
      }

      final allEvents = <Event>[];
      
      for (final calendar in calendarsToSearch) {
        final result = await _deviceCalendar.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(startDate: start, endDate: end),
        );
        
        if (result.isSuccess && result.data != null) {
          allEvents.addAll(result.data!);
        }
      }

      // 按开始时间排序
      allEvents.sort((a, b) => 
          (a.start ?? DateTime.now()).compareTo(b.start ?? DateTime.now()));
      
      return allEvents;
    } catch (e) {
      debugPrint('获取系统日历事件失败: $e');
      return [];
    }
  }

  /// 将系统日历事件导入为日程
  Schedule? eventToSchedule(Event event) {
    if (event.title == null) return null;
    
    return Schedule(
      id: event.eventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: event.title!,
      description: event.description,
      startTime: event.start?.toLocal() ?? DateTime.now(),
      endTime: event.end?.toLocal(),
      isAllDay: event.allDay ?? false,
      location: event.location,
      reminderTimeIndex: 0,
      repeatTypeIndex: 0,
    );
  }
}
