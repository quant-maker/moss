import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/dev_todo.dart';

/// DevTodo 服务 - 管理开发任务的 CRUD 操作
/// 参考 opencode 的 TodoWrite/TodoRead 机制
class DevTodoService {
  static const String _boxName = 'dev_todos';
  Box<DevTodo>? _box;
  bool _initialized = false;

  /// 当前会话 ID
  String? _currentSessionId;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(DevTodoAdapter());
      }
      _box = await Hive.openBox<DevTodo>(_boxName);
      _initialized = true;
      debugPrint('[DevTodoService] Initialized with ${_box!.length} todos');
    } catch (e) {
      debugPrint('[DevTodoService] Initialize error: $e');
    }
  }

  /// 设置当前会话 ID
  void setSessionId(String sessionId) {
    _currentSessionId = sessionId;
  }

  /// 获取当前会话 ID
  String get currentSessionId =>
      _currentSessionId ?? DateTime.now().millisecondsSinceEpoch.toString();

  /// 创建新任务
  Future<DevTodo> create({
    required String content,
    DevTodoPriority priority = DevTodoPriority.medium,
    String? sessionId,
    String? parentId,
  }) async {
    await initialize();

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final todos = getBySession(sessionId ?? currentSessionId);
    final orderIndex = todos.isEmpty ? 0 : todos.length;

    final todo = DevTodo(
      id: id,
      content: content,
      priorityIndex: priority.index,
      sessionId: sessionId ?? currentSessionId,
      parentId: parentId,
      orderIndex: orderIndex,
    );

    await _box!.put(id, todo);
    debugPrint('[DevTodoService] Created: ${todo.content}');
    return todo;
  }

  /// 批量更新任务列表（opencode 风格的 todowrite）
  /// 这是核心方法：接收完整的 todo 列表并更新
  Future<List<DevTodo>> updateAll(List<Map<String, dynamic>> todosJson,
      {String? sessionId}) async {
    await initialize();

    final sid = sessionId ?? currentSessionId;
    final existingTodos = getBySession(sid);
    final existingIds = existingTodos.map((t) => t.id).toSet();
    final newIds = <String>{};

    final updatedTodos = <DevTodo>[];

    for (int i = 0; i < todosJson.length; i++) {
      final json = todosJson[i];
      final id = json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString() + '_$i';
      newIds.add(id);

      DevTodo todo;
      if (existingIds.contains(id)) {
        // 更新现有任务
        final existing = _box!.get(id)!;
        todo = existing.copyWith(
          content: json['content'] as String?,
          status: _parseStatus(json['status']),
          priority: _parsePriority(json['priority']),
          orderIndex: i,
        );
      } else {
        // 创建新任务
        todo = DevTodo(
          id: id,
          content: json['content'] as String? ?? '',
          statusIndex: _parseStatusIndex(json['status']),
          priorityIndex: _parsePriorityIndex(json['priority']),
          sessionId: sid,
          orderIndex: i,
        );
      }

      await _box!.put(id, todo);
      updatedTodos.add(todo);
    }

    // 删除不在新列表中的任务
    for (final existingId in existingIds) {
      if (!newIds.contains(existingId)) {
        await _box!.delete(existingId);
      }
    }

    debugPrint(
        '[DevTodoService] Updated ${updatedTodos.length} todos for session $sid');
    return updatedTodos;
  }

  /// 获取单个任务
  DevTodo? get(String id) {
    return _box?.get(id);
  }

  /// 获取所有任务
  List<DevTodo> getAll() {
    if (_box == null) return [];
    return _box!.values.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  /// 获取当前会话的任务
  List<DevTodo> getBySession(String? sessionId) {
    if (_box == null) return [];
    final sid = sessionId ?? currentSessionId;
    return _box!.values
        .where((t) => t.sessionId == sid)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  /// 获取当前会话的活跃任务（待处理 + 进行中）
  List<DevTodo> getActiveBySession({String? sessionId}) {
    return getBySession(sessionId).where((t) => t.isActive).toList();
  }

  /// 获取当前进行中的任务（应该只有一个）
  DevTodo? getInProgress({String? sessionId}) {
    final todos = getBySession(sessionId);
    try {
      return todos.firstWhere((t) => t.isInProgress);
    } catch (_) {
      return null;
    }
  }

  /// 更新任务状态
  Future<DevTodo?> updateStatus(String id, DevTodoStatus status) async {
    await initialize();

    final todo = _box?.get(id);
    if (todo == null) return null;

    // 如果设置为进行中，先将其他进行中的任务设为待处理
    if (status == DevTodoStatus.inProgress) {
      final inProgressTodo = getInProgress(sessionId: todo.sessionId);
      if (inProgressTodo != null && inProgressTodo.id != id) {
        inProgressTodo.status = DevTodoStatus.pending;
        await _box!.put(inProgressTodo.id, inProgressTodo);
      }
    }

    todo.status = status;
    await _box!.put(id, todo);

    debugPrint('[DevTodoService] Updated status: ${todo.content} -> $status');
    return todo;
  }

  /// 将任务标记为进行中
  Future<DevTodo?> markInProgress(String id) async {
    return updateStatus(id, DevTodoStatus.inProgress);
  }

  /// 将任务标记为完成
  Future<DevTodo?> markCompleted(String id) async {
    return updateStatus(id, DevTodoStatus.completed);
  }

  /// 将任务标记为取消
  Future<DevTodo?> markCancelled(String id) async {
    return updateStatus(id, DevTodoStatus.cancelled);
  }

  /// 删除任务
  Future<void> delete(String id) async {
    await initialize();
    await _box?.delete(id);
    debugPrint('[DevTodoService] Deleted: $id');
  }

  /// 清空会话的所有任务
  Future<void> clearSession(String? sessionId) async {
    await initialize();
    final todos = getBySession(sessionId);
    for (final todo in todos) {
      await _box!.delete(todo.id);
    }
    debugPrint('[DevTodoService] Cleared session: $sessionId');
  }

  /// 清空所有任务
  Future<void> clearAll() async {
    await initialize();
    await _box?.clear();
    debugPrint('[DevTodoService] Cleared all todos');
  }

  /// 获取统计信息
  DevTodoStats getStats({String? sessionId}) {
    final todos = getBySession(sessionId);
    return DevTodoStats.fromList(todos);
  }

  /// 格式化任务列表为字符串（用于显示）
  String formatTodos({String? sessionId, bool showCompleted = true}) {
    final todos = getBySession(sessionId);
    if (todos.isEmpty) return '暂无任务';

    final buffer = StringBuffer();
    for (final todo in todos) {
      if (!showCompleted && (todo.isCompleted || todo.isCancelled)) continue;
      buffer.writeln('${todo.statusIcon} ${todo.content}');
    }
    return buffer.toString().trim();
  }

  // Helper methods
  DevTodoStatus? _parseStatus(dynamic value) {
    if (value == null) return null;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'pending':
        return DevTodoStatus.pending;
      case 'in_progress':
      case 'inprogress':
        return DevTodoStatus.inProgress;
      case 'completed':
        return DevTodoStatus.completed;
      case 'cancelled':
        return DevTodoStatus.cancelled;
      default:
        return null;
    }
  }

  int _parseStatusIndex(dynamic value) {
    final status = _parseStatus(value);
    return status?.index ?? 0;
  }

  DevTodoPriority? _parsePriority(dynamic value) {
    if (value == null) return null;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'low':
        return DevTodoPriority.low;
      case 'medium':
        return DevTodoPriority.medium;
      case 'high':
        return DevTodoPriority.high;
      default:
        return null;
    }
  }

  int _parsePriorityIndex(dynamic value) {
    final priority = _parsePriority(value);
    return priority?.index ?? 1;
  }
}

/// DevTodo 状态
class DevTodoState {
  final List<DevTodo> todos;
  final bool isLoading;
  final String? error;

  DevTodoState({
    required this.todos,
    this.isLoading = false,
    this.error,
  });

  DevTodoState copyWith({
    List<DevTodo>? todos,
    bool? isLoading,
    String? error,
  }) {
    return DevTodoState(
      todos: todos ?? this.todos,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 活跃任务（待处理 + 进行中）
  List<DevTodo> get active => todos.where((t) => t.isActive).toList();

  /// 当前进行中的任务
  DevTodo? get inProgress {
    try {
      return todos.firstWhere((t) => t.isInProgress);
    } catch (_) {
      return null;
    }
  }

  /// 统计
  DevTodoStats get stats => DevTodoStats.fromList(todos);
}

/// DevTodo 状态通知器
class DevTodoNotifier extends StateNotifier<DevTodoState> {
  final DevTodoService _service;

  DevTodoNotifier(this._service) : super(DevTodoState(todos: [])) {
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.initialize();
      final todos = _service.getBySession(null);
      state = DevTodoState(todos: todos);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 设置会话 ID
  void setSessionId(String sessionId) {
    _service.setSessionId(sessionId);
    _refreshTodos();
  }

  /// 刷新任务列表
  void _refreshTodos() {
    final todos = _service.getBySession(null);
    state = DevTodoState(todos: todos);
  }

  /// 批量更新任务（todowrite 风格）
  Future<void> updateAll(List<Map<String, dynamic>> todosJson) async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.updateAll(todosJson);
      _refreshTodos();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 创建任务
  Future<DevTodo> create({
    required String content,
    DevTodoPriority priority = DevTodoPriority.medium,
  }) async {
    final todo = await _service.create(content: content, priority: priority);
    _refreshTodos();
    return todo;
  }

  /// 更新任务状态
  Future<void> updateStatus(String id, DevTodoStatus status) async {
    await _service.updateStatus(id, status);
    _refreshTodos();
  }

  /// 标记为进行中
  Future<void> markInProgress(String id) async {
    await _service.markInProgress(id);
    _refreshTodos();
  }

  /// 标记为完成
  Future<void> markCompleted(String id) async {
    await _service.markCompleted(id);
    _refreshTodos();
  }

  /// 删除任务
  Future<void> delete(String id) async {
    await _service.delete(id);
    _refreshTodos();
  }

  /// 清空当前会话
  Future<void> clearSession() async {
    await _service.clearSession(null);
    _refreshTodos();
  }
}

/// DevTodoService Provider
final devTodoServiceProvider = Provider<DevTodoService>((ref) {
  return DevTodoService();
});

/// DevTodo 状态 Provider
final devTodoProvider =
    StateNotifierProvider<DevTodoNotifier, DevTodoState>((ref) {
  final service = ref.watch(devTodoServiceProvider);
  return DevTodoNotifier(service);
});
