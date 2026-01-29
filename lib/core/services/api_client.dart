import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import '../storage/local_storage.dart';

/// API 响应模型
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResponse({required this.success, this.data, this.error});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    return ApiResponse(
      success: json['success'] ?? false,
      data: json['data'] != null && fromData != null
          ? fromData(json['data'])
          : json['data'],
      error: json['error'],
    );
  }
}

/// API 客户端服务
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  Dio? _dio;
  String? _baseUrl;
  String? _userId;

  /// 初始化
  Future<void> initialize() async {
    final storage = LocalStorage();
    await storage.initialize();
    
    _baseUrl = storage.getServerUrl();
    _userId = storage.getUserId();

    _setupDio();
  }

  /// 设置服务器地址
  Future<void> setServerUrl(String url) async {
    _baseUrl = url;
    final storage = LocalStorage();
    await storage.setServerUrl(url);
    _setupDio();
  }

  /// 设置用户 ID
  Future<void> setUserId(String userId) async {
    _userId = userId;
    final storage = LocalStorage();
    await storage.setUserId(userId);
    _setupDio();
  }

  /// 配置 Dio
  void _setupDio() {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      _dio = null;
      return;
    }

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl!,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        if (_userId != null) 'X-User-ID': _userId,
      },
    ));

    // 添加日志拦截器
    if (kDebugMode) {
      _dio!.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint(o.toString()),
      ));
    }

    // 添加错误处理拦截器
    _dio!.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        debugPrint('API 错误: ${error.message}');
        handler.next(error);
      },
    ));
  }

  /// 是否已配置服务器
  bool get isConfigured => _dio != null;

  /// 获取服务器地址
  String? get serverUrl => _baseUrl;

  // === 健康检查 ===

  /// 测试服务器连接
  Future<bool> testConnection() async {
    if (_dio == null) return false;

    try {
      final response = await _dio!.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('连接测试失败: $e');
      return false;
    }
  }

  // === LLM API ===

  /// 聊天 (非流式)
  Future<ApiResponse<Map<String, dynamic>>> chat({
    required String provider,
    required List<Map<String, dynamic>> messages,
    String? model,
    List<Map<String, dynamic>>? tools,
  }) async {
    if (_dio == null) {
      return ApiResponse(success: false, error: '未配置服务器');
    }

    try {
      final response = await _dio!.post('/api/v1/chat', data: {
        'provider': provider,
        'model': model,
        'messages': messages,
        'tools': tools,
      });

      return ApiResponse.fromJson(response.data, (data) => data);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data?['error'] ?? e.message,
      );
    }
  }

  /// 流式聊天
  Stream<String> chatStream({
    required String provider,
    required List<Map<String, dynamic>> messages,
    String? model,
  }) async* {
    if (_dio == null) {
      yield '[ERROR] 未配置服务器';
      return;
    }

    try {
      final response = await _dio!.post<ResponseBody>(
        '/api/v1/chat/stream',
        data: {
          'provider': provider,
          'model': model,
          'messages': messages,
        },
        options: Options(responseType: ResponseType.stream),
      );

      await for (final chunk in response.data!.stream) {
        final text = utf8.decode(chunk);
        for (final line in text.split('\n')) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data != '[DONE]' && data.isNotEmpty) {
              yield data;
            }
          }
        }
      }
    } on DioException catch (e) {
      yield '[ERROR] ${e.message}';
    }
  }

  // === 日程 API ===

  /// 获取日程列表
  Future<ApiResponse<List<Schedule>>> getSchedules({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_dio == null) {
      return ApiResponse(success: false, error: '未配置服务器');
    }

    try {
      final params = <String, dynamic>{};
      if (start != null) params['start'] = start.toIso8601String();
      if (end != null) params['end'] = end.toIso8601String();

      final response = await _dio!.get(
        '/api/v1/schedules',
        queryParameters: params,
      );

      return ApiResponse.fromJson(response.data, (data) {
        return (data as List)
            .map((e) => Schedule.fromJson(e))
            .toList();
      });
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data?['error'] ?? e.message,
      );
    }
  }

  /// 创建日程
  Future<ApiResponse<Schedule>> createSchedule(Schedule schedule) async {
    if (_dio == null) {
      return ApiResponse(success: false, error: '未配置服务器');
    }

    try {
      final response = await _dio!.post(
        '/api/v1/schedules',
        data: schedule.toJson(),
      );

      return ApiResponse.fromJson(
        response.data,
        (data) => Schedule.fromJson(data),
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data?['error'] ?? e.message,
      );
    }
  }

  /// 更新日程
  Future<ApiResponse<Schedule>> updateSchedule(Schedule schedule) async {
    if (_dio == null) {
      return ApiResponse(success: false, error: '未配置服务器');
    }

    try {
      final response = await _dio!.put(
        '/api/v1/schedules/${schedule.id}',
        data: schedule.toJson(),
      );

      return ApiResponse.fromJson(
        response.data,
        (data) => Schedule.fromJson(data),
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data?['error'] ?? e.message,
      );
    }
  }

  /// 删除日程
  Future<ApiResponse<void>> deleteSchedule(String id) async {
    if (_dio == null) {
      return ApiResponse(success: false, error: '未配置服务器');
    }

    try {
      final response = await _dio!.delete('/api/v1/schedules/$id');
      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data?['error'] ?? e.message,
      );
    }
  }

  // === 任务 API ===

  /// 获取任务列表
  Future<ApiResponse<List<Task>>> getTasks({String? status}) async {
    if (_dio == null) {
      return ApiResponse(success: false, error: '未配置服务器');
    }

    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;

      final response = await _dio!.get(
        '/api/v1/tasks',
        queryParameters: params,
      );

      return ApiResponse.fromJson(response.data, (data) {
        return (data as List).map((e) => Task.fromJson(e)).toList();
      });
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data?['error'] ?? e.message,
      );
    }
  }

  /// 创建任务
  Future<ApiResponse<Task>> createTask(Task task) async {
    if (_dio == null) {
      return ApiResponse(success: false, error: '未配置服务器');
    }

    try {
      final response = await _dio!.post(
        '/api/v1/tasks',
        data: task.toJson(),
      );

      return ApiResponse.fromJson(
        response.data,
        (data) => Task.fromJson(data),
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data?['error'] ?? e.message,
      );
    }
  }

  /// 更新任务
  Future<ApiResponse<Task>> updateTask(Task task) async {
    if (_dio == null) {
      return ApiResponse(success: false, error: '未配置服务器');
    }

    try {
      final response = await _dio!.put(
        '/api/v1/tasks/${task.id}',
        data: task.toJson(),
      );

      return ApiResponse.fromJson(
        response.data,
        (data) => Task.fromJson(data),
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data?['error'] ?? e.message,
      );
    }
  }

  /// 删除任务
  Future<ApiResponse<void>> deleteTask(String id) async {
    if (_dio == null) {
      return ApiResponse(success: false, error: '未配置服务器');
    }

    try {
      final response = await _dio!.delete('/api/v1/tasks/$id');
      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data?['error'] ?? e.message,
      );
    }
  }

  // === 同步 API ===

  /// 同步数据
  Future<ApiResponse<SyncResponse>> sync({
    DateTime? lastSyncTime,
    List<Schedule>? schedules,
    List<Task>? tasks,
  }) async {
    if (_dio == null) {
      return ApiResponse(success: false, error: '未配置服务器');
    }

    try {
      final response = await _dio!.post('/api/v1/sync', data: {
        'last_sync_time': lastSyncTime?.toIso8601String(),
        'schedules': schedules?.map((s) => s.toJson()).toList(),
        'tasks': tasks?.map((t) => t.toJson()).toList(),
      });

      return ApiResponse.fromJson(
        response.data,
        (data) => SyncResponse.fromJson(data),
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data?['error'] ?? e.message,
      );
    }
  }
}

/// 同步响应
class SyncResponse {
  final DateTime syncTime;
  final List<Schedule> schedules;
  final List<Task> tasks;

  SyncResponse({
    required this.syncTime,
    required this.schedules,
    required this.tasks,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      syncTime: DateTime.parse(json['sync_time']),
      schedules: (json['schedules'] as List?)
          ?.map((e) => Schedule.fromJson(e))
          .toList() ?? [],
      tasks: (json['tasks'] as List?)
          ?.map((e) => Task.fromJson(e))
          .toList() ?? [],
    );
  }
}

/// API 客户端 Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
