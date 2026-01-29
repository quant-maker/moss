import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule.dart';
import 'notification_service.dart';

/// 日程存储服务
class ScheduleService {
  static const String _boxName = 'schedules';
  Box<Schedule>? _box;
  final NotificationService _notificationService = NotificationService();

  /// 初始化
  Future<void> initialize() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ScheduleAdapter());
    }
    _box = await Hive.openBox<Schedule>(_boxName);
  }

  /// 确保已初始化
  Box<Schedule> get _scheduleBox {
    if (_box == null) {
      throw StateError('ScheduleService 未初始化，请先调用 initialize()');
    }
    return _box!;
  }

  /// 获取所有日程
  List<Schedule> getAll() {
    return _scheduleBox.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 获取指定日期的日程
  List<Schedule> getByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return _scheduleBox.values.where((schedule) {
      return schedule.startTime.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
          schedule.startTime.isBefore(endOfDay);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 获取日期范围内的日程
  List<Schedule> getByDateRange(DateTime start, DateTime end) {
    return _scheduleBox.values.where((schedule) {
      return schedule.startTime.isAfter(start.subtract(const Duration(seconds: 1))) &&
          schedule.startTime.isBefore(end.add(const Duration(seconds: 1)));
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 获取今日日程
  List<Schedule> getToday() {
    return getByDate(DateTime.now());
  }

  /// 获取即将到来的日程
  List<Schedule> getUpcoming({int days = 7}) {
    final now = DateTime.now();
    final end = now.add(Duration(days: days));
    return getByDateRange(now, end);
  }

  /// 根据 ID 获取日程
  Schedule? getById(String id) {
    try {
      return _scheduleBox.values.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 创建日程
  Future<Schedule> create({
    required String title,
    String? description,
    required DateTime startTime,
    DateTime? endTime,
    bool isAllDay = false,
    String? location,
    RepeatType repeatType = RepeatType.none,
    ReminderTime reminderTime = ReminderTime.none,
    String? color,
  }) async {
    final schedule = Schedule(
      id: const Uuid().v4(),
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      location: location,
      repeatTypeIndex: repeatType.index,
      reminderTimeIndex: reminderTime.index,
      color: color,
    );
    
    await _scheduleBox.put(schedule.id, schedule);
    
    // 调度通知提醒
    if (reminderTime != ReminderTime.none) {
      await _notificationService.scheduleScheduleNotification(schedule);
    }
    
    return schedule;
  }

  /// 更新日程
  Future<void> update(Schedule schedule) async {
    final updated = schedule.copyWith();
    await _scheduleBox.put(schedule.id, updated);
    
    // 更新通知
    await _notificationService.cancelScheduleNotification(schedule.id);
    if (schedule.reminderTime != ReminderTime.none && !schedule.isCompleted) {
      await _notificationService.scheduleScheduleNotification(updated);
    }
  }

  /// 删除日程
  Future<void> delete(String id) async {
    await _notificationService.cancelScheduleNotification(id);
    await _scheduleBox.delete(id);
  }

  /// 标记完成/未完成
  Future<void> toggleComplete(String id) async {
    final schedule = getById(id);
    if (schedule != null) {
      final updated = schedule.copyWith(isCompleted: !schedule.isCompleted);
      await _scheduleBox.put(id, updated);
    }
  }

  /// 清空所有日程
  Future<void> clear() async {
    await _scheduleBox.clear();
  }

  /// 搜索日程
  List<Schedule> search(String query) {
    final lowerQuery = query.toLowerCase();
    return _scheduleBox.values.where((schedule) {
      return schedule.title.toLowerCase().contains(lowerQuery) ||
          (schedule.description?.toLowerCase().contains(lowerQuery) ?? false) ||
          (schedule.location?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 获取有日程的日期列表（用于日历标记）
  Set<DateTime> getScheduledDates({DateTime? start, DateTime? end}) {
    final schedules = start != null && end != null
        ? getByDateRange(start, end)
        : getAll();
    
    return schedules.map((s) => DateTime(
      s.startTime.year,
      s.startTime.month,
      s.startTime.day,
    )).toSet();
  }

  /// 检测日程冲突
  /// 返回与指定时间范围冲突的日程列表
  /// [excludeId] 可选，排除指定ID的日程（用于编辑时排除自己）
  List<Schedule> checkConflicts({
    required DateTime startTime,
    required DateTime endTime,
    String? excludeId,
  }) {
    return _scheduleBox.values.where((schedule) {
      // 排除自己
      if (excludeId != null && schedule.id == excludeId) {
        return false;
      }
      
      // 跳过全天事件
      if (schedule.isAllDay) {
        return false;
      }
      
      // 已完成的日程不算冲突
      if (schedule.isCompleted) {
        return false;
      }
      
      final scheduleEnd = schedule.endTime ?? schedule.startTime.add(const Duration(hours: 1));
      
      // 检查时间重叠
      // 两个时间段重叠的条件: A开始 < B结束 && A结束 > B开始
      return schedule.startTime.isBefore(endTime) && scheduleEnd.isAfter(startTime);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 检测日程冲突（简化版，用于创建时）
  /// 自动计算结束时间为开始时间 + 1小时（如果未指定）
  List<Schedule> checkConflictsForNew({
    required DateTime startTime,
    DateTime? endTime,
    bool isAllDay = false,
  }) {
    // 全天事件不检查冲突
    if (isAllDay) {
      return [];
    }
    
    final actualEndTime = endTime ?? startTime.add(const Duration(hours: 1));
    return checkConflicts(startTime: startTime, endTime: actualEndTime);
  }

  /// 获取即将开始的日程（指定分钟内）
  List<Schedule> getUpcomingInMinutes(int minutes) {
    final now = DateTime.now();
    final end = now.add(Duration(minutes: minutes));
    
    return _scheduleBox.values.where((schedule) {
      if (schedule.isCompleted) return false;
      return schedule.startTime.isAfter(now) && 
             schedule.startTime.isBefore(end);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 获取过期未完成的日程
  List<Schedule> getOverdue() {
    final now = DateTime.now();
    return _scheduleBox.values.where((schedule) {
      if (schedule.isCompleted) return false;
      final endTime = schedule.endTime ?? schedule.startTime.add(const Duration(hours: 1));
      return endTime.isBefore(now);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 获取明天的日程
  List<Schedule> getTomorrow() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return getByDate(tomorrow);
  }

  /// 按重要程度获取日程（有提醒的优先）
  List<Schedule> getImportantUpcoming({int days = 7}) {
    return getUpcoming(days: days)
      .where((s) => !s.isCompleted && s.reminderTime != ReminderTime.none)
      .toList();
  }
}

/// 日程服务 Provider
final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService();
});

/// 日程列表状态
class ScheduleListState {
  final List<Schedule> schedules;
  final DateTime selectedDate;
  final bool isLoading;
  final String? error;

  ScheduleListState({
    required this.schedules,
    required this.selectedDate,
    this.isLoading = false,
    this.error,
  });

  ScheduleListState copyWith({
    List<Schedule>? schedules,
    DateTime? selectedDate,
    bool? isLoading,
    String? error,
  }) {
    return ScheduleListState(
      schedules: schedules ?? this.schedules,
      selectedDate: selectedDate ?? this.selectedDate,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 日程列表控制器
class ScheduleListNotifier extends StateNotifier<ScheduleListState> {
  final ScheduleService _service;

  ScheduleListNotifier(this._service) : super(ScheduleListState(
    schedules: [],
    selectedDate: DateTime.now(),
  )) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.initialize();
      await loadSchedules();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载日程
  Future<void> loadSchedules() async {
    final schedules = _service.getByDate(state.selectedDate);
    state = state.copyWith(schedules: schedules, isLoading: false);
  }

  /// 选择日期
  Future<void> selectDate(DateTime date) async {
    state = state.copyWith(selectedDate: date, isLoading: true);
    await loadSchedules();
  }

  /// 创建日程
  Future<Schedule> createSchedule({
    required String title,
    String? description,
    required DateTime startTime,
    DateTime? endTime,
    bool isAllDay = false,
    String? location,
    RepeatType repeatType = RepeatType.none,
    ReminderTime reminderTime = ReminderTime.none,
  }) async {
    final schedule = await _service.create(
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      location: location,
      repeatType: repeatType,
      reminderTime: reminderTime,
    );
    await loadSchedules();
    return schedule;
  }

  /// 更新日程
  Future<void> updateSchedule(Schedule schedule) async {
    await _service.update(schedule);
    await loadSchedules();
  }

  /// 删除日程
  Future<void> deleteSchedule(String id) async {
    await _service.delete(id);
    await loadSchedules();
  }

  /// 切换完成状态
  Future<void> toggleComplete(String id) async {
    await _service.toggleComplete(id);
    await loadSchedules();
  }

  /// 刷新
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await loadSchedules();
  }
}

/// 日程列表 Provider
final scheduleListProvider = StateNotifierProvider<ScheduleListNotifier, ScheduleListState>((ref) {
  final service = ref.watch(scheduleServiceProvider);
  return ScheduleListNotifier(service);
});
