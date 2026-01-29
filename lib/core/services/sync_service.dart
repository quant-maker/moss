import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import '../storage/local_storage.dart';
import 'api_client.dart';
import 'schedule_service.dart';
import 'task_service.dart';

/// 同步状态
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

/// 同步结果
class SyncResult {
  final bool success;
  final String? error;
  final int schedulesUpdated;
  final int tasksUpdated;
  final DateTime? syncTime;

  SyncResult({
    required this.success,
    this.error,
    this.schedulesUpdated = 0,
    this.tasksUpdated = 0,
    this.syncTime,
  });
}

/// 数据同步服务
class SyncService {
  final ApiClient _apiClient;
  final ScheduleService _scheduleService;
  final TaskService _taskService;
  final LocalStorage _localStorage;

  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncTime;
  String? _lastError;

  SyncService({
    ApiClient? apiClient,
    required ScheduleService scheduleService,
    required TaskService taskService,
    required LocalStorage localStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _scheduleService = scheduleService,
        _taskService = taskService,
        _localStorage = localStorage;

  /// 当前同步状态
  SyncStatus get status => _status;

  /// 最后同步时间
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 最后错误信息
  String? get lastError => _lastError;

  /// 是否可以同步
  bool get canSync => _apiClient.isConfigured;

  /// 初始化
  Future<void> initialize() async {
    _lastSyncTime = _localStorage.getLastSyncTime();
  }

  /// 执行同步
  Future<SyncResult> sync() async {
    if (!canSync) {
      return SyncResult(
        success: false,
        error: '未配置服务器',
      );
    }

    if (_status == SyncStatus.syncing) {
      return SyncResult(
        success: false,
        error: '正在同步中',
      );
    }

    _status = SyncStatus.syncing;
    _lastError = null;

    try {
      // 获取本地数据
      final localSchedules = _scheduleService.getAll();
      final localTasks = _taskService.getAll();

      // 调用同步 API
      final response = await _apiClient.sync(
        lastSyncTime: _lastSyncTime,
        schedules: localSchedules,
        tasks: localTasks,
      );

      if (!response.success) {
        throw Exception(response.error ?? '同步失败');
      }

      final syncData = response.data!;
      int schedulesUpdated = 0;
      int tasksUpdated = 0;

      // 合并服务器返回的日程数据
      for (final serverSchedule in syncData.schedules) {
        final local = _scheduleService.getById(serverSchedule.id);
        if (local == null) {
          // 本地不存在，创建
          await _saveSchedule(serverSchedule);
          schedulesUpdated++;
        } else if (_shouldUpdateLocal(local.updatedAt, serverSchedule.updatedAt)) {
          // 服务器数据更新，覆盖本地
          await _saveSchedule(serverSchedule);
          schedulesUpdated++;
        }
      }

      // 合并服务器返回的任务数据
      for (final serverTask in syncData.tasks) {
        final local = _taskService.getById(serverTask.id);
        if (local == null) {
          // 本地不存在，创建
          await _saveTask(serverTask);
          tasksUpdated++;
        } else if (_shouldUpdateLocal(local.updatedAt, serverTask.updatedAt)) {
          // 服务器数据更新，覆盖本地
          await _saveTask(serverTask);
          tasksUpdated++;
        }
      }

      // 更新最后同步时间
      _lastSyncTime = syncData.syncTime;
      await _localStorage.setLastSyncTime(_lastSyncTime!);

      _status = SyncStatus.success;
      
      debugPrint('同步完成: $schedulesUpdated 个日程, $tasksUpdated 个任务');
      
      return SyncResult(
        success: true,
        schedulesUpdated: schedulesUpdated,
        tasksUpdated: tasksUpdated,
        syncTime: _lastSyncTime,
      );
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      debugPrint('同步失败: $_lastError');
      
      return SyncResult(
        success: false,
        error: _lastError,
      );
    }
  }

  /// 判断是否应该用服务器数据更新本地
  bool _shouldUpdateLocal(DateTime localTime, DateTime serverTime) {
    return serverTime.isAfter(localTime);
  }

  /// 保存日程到本地
  Future<void> _saveSchedule(Schedule schedule) async {
    await _scheduleService.update(schedule);
  }

  /// 保存任务到本地
  Future<void> _saveTask(Task task) async {
    await _taskService.update(task);
  }

  /// 上传单个日程
  Future<bool> uploadSchedule(Schedule schedule) async {
    if (!canSync) return false;

    try {
      final response = await _apiClient.createSchedule(schedule);
      return response.success;
    } catch (e) {
      debugPrint('上传日程失败: $e');
      return false;
    }
  }

  /// 上传单个任务
  Future<bool> uploadTask(Task task) async {
    if (!canSync) return false;

    try {
      final response = await _apiClient.createTask(task);
      return response.success;
    } catch (e) {
      debugPrint('上传任务失败: $e');
      return false;
    }
  }

  /// 从服务器删除日程
  Future<bool> deleteScheduleFromServer(String id) async {
    if (!canSync) return false;

    try {
      final response = await _apiClient.deleteSchedule(id);
      return response.success;
    } catch (e) {
      debugPrint('删除远程日程失败: $e');
      return false;
    }
  }

  /// 从服务器删除任务
  Future<bool> deleteTaskFromServer(String id) async {
    if (!canSync) return false;

    try {
      final response = await _apiClient.deleteTask(id);
      return response.success;
    } catch (e) {
      debugPrint('删除远程任务失败: $e');
      return false;
    }
  }
}

/// 同步服务状态
class SyncServiceState {
  final SyncStatus status;
  final DateTime? lastSyncTime;
  final String? error;

  SyncServiceState({
    this.status = SyncStatus.idle,
    this.lastSyncTime,
    this.error,
  });

  SyncServiceState copyWith({
    SyncStatus? status,
    DateTime? lastSyncTime,
    String? error,
  }) {
    return SyncServiceState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      error: error,
    );
  }
}

/// 同步服务 Notifier
class SyncServiceNotifier extends StateNotifier<SyncServiceState> {
  final SyncService _service;

  SyncServiceNotifier(this._service) : super(SyncServiceState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _service.initialize();
    state = state.copyWith(
      lastSyncTime: _service.lastSyncTime,
    );
  }

  /// 执行同步
  Future<SyncResult> sync() async {
    state = state.copyWith(status: SyncStatus.syncing, error: null);
    
    final result = await _service.sync();
    
    state = state.copyWith(
      status: result.success ? SyncStatus.success : SyncStatus.error,
      lastSyncTime: result.syncTime ?? state.lastSyncTime,
      error: result.error,
    );
    
    return result;
  }

  /// 是否可以同步
  bool get canSync => _service.canSync;
}

/// 同步服务 Provider
final syncServiceProvider = StateNotifierProvider<SyncServiceNotifier, SyncServiceState>((ref) {
  final scheduleService = ref.watch(scheduleServiceProvider);
  final taskService = ref.watch(taskServiceProvider);
  final localStorage = ref.watch(localStorageProvider);
  
  final syncService = SyncService(
    scheduleService: scheduleService,
    taskService: taskService,
    localStorage: localStorage,
  );
  
  return SyncServiceNotifier(syncService);
});
