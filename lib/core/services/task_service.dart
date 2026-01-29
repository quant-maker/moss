import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import 'notification_service.dart';

/// 任务存储服务
class TaskService {
  static const String _boxName = 'tasks';
  Box<Task>? _box;
  final NotificationService _notificationService = NotificationService();

  /// 初始化
  Future<void> initialize() async {
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(TaskAdapter());
    }
    _box = await Hive.openBox<Task>(_boxName);
  }

  /// 确保已初始化
  Box<Task> get _taskBox {
    if (_box == null) {
      throw StateError('TaskService 未初始化，请先调用 initialize()');
    }
    return _box!;
  }

  /// 获取所有任务
  List<Task> getAll() {
    return _taskBox.values.toList()
      ..sort((a, b) {
        // 先按状态排序（未完成在前）
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        // 再按优先级排序（高在前）
        if (a.priorityIndex != b.priorityIndex) {
          return b.priorityIndex.compareTo(a.priorityIndex);
        }
        // 最后按创建时间排序
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  /// 获取未完成的任务
  List<Task> getPending() {
    return _taskBox.values
        .where((task) => task.status == TaskStatus.pending || 
                         task.status == TaskStatus.inProgress)
        .toList()
      ..sort((a, b) {
        if (a.priorityIndex != b.priorityIndex) {
          return b.priorityIndex.compareTo(a.priorityIndex);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  /// 获取已完成的任务
  List<Task> getCompleted() {
    return _taskBox.values
        .where((task) => task.status == TaskStatus.completed)
        .toList()
      ..sort((a, b) => (b.completedAt ?? b.updatedAt)
          .compareTo(a.completedAt ?? a.updatedAt));
  }

  /// 按分类获取任务
  List<Task> getByCategory(String category) {
    return _taskBox.values
        .where((task) => task.category == category)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 获取所有分类
  List<String> getCategories() {
    final categories = <String>{};
    for (final task in _taskBox.values) {
      if (task.category != null && task.category!.isNotEmpty) {
        categories.add(task.category!);
      }
    }
    return categories.toList()..sort();
  }

  /// 获取过期任务
  List<Task> getOverdue() {
    final now = DateTime.now();
    return _taskBox.values
        .where((task) => 
            task.dueDate != null && 
            task.dueDate!.isBefore(now) && 
            !task.isCompleted)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  /// 获取今日到期任务
  List<Task> getDueToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    return _taskBox.values
        .where((task) => 
            task.dueDate != null && 
            task.dueDate!.isAfter(today.subtract(const Duration(seconds: 1))) &&
            task.dueDate!.isBefore(tomorrow) &&
            !task.isCompleted)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  /// 根据 ID 获取任务
  Task? getById(String id) {
    try {
      return _taskBox.values.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 创建任务
  Future<Task> create({
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    String? category,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    final task = Task(
      id: const Uuid().v4(),
      title: title,
      description: description,
      priorityIndex: priority.index,
      statusIndex: TaskStatus.pending.index,
      category: category,
      dueDate: dueDate,
      tags: tags,
    );
    
    await _taskBox.put(task.id, task);
    
    // 调度通知提醒
    if (dueDate != null) {
      await _notificationService.scheduleTaskNotification(task);
    }
    
    return task;
  }

  /// 更新任务
  Future<void> update(Task task) async {
    final updated = task.copyWith();
    await _taskBox.put(task.id, updated);
    
    // 更新通知
    await _notificationService.cancelTaskNotification(task.id);
    if (task.dueDate != null && !task.isCompleted) {
      await _notificationService.scheduleTaskNotification(updated);
    }
  }

  /// 删除任务
  Future<void> delete(String id) async {
    await _notificationService.cancelTaskNotification(id);
    await _taskBox.delete(id);
  }

  /// 标记完成
  Future<void> complete(String id) async {
    final task = getById(id);
    if (task != null) {
      final updated = task.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
      );
      await _taskBox.put(id, updated);
      await _notificationService.cancelTaskNotification(id);
    }
  }

  /// 标记未完成
  Future<void> uncomplete(String id) async {
    final task = getById(id);
    if (task != null) {
      final updated = task.copyWith(
        status: TaskStatus.pending,
      );
      await _taskBox.put(id, updated);
    }
  }

  /// 切换完成状态
  Future<void> toggleComplete(String id) async {
    final task = getById(id);
    if (task != null) {
      if (task.isCompleted) {
        await uncomplete(id);
      } else {
        await complete(id);
      }
    }
  }

  /// 搜索任务
  List<Task> search(String query) {
    final lowerQuery = query.toLowerCase();
    return _taskBox.values.where((task) {
      return task.title.toLowerCase().contains(lowerQuery) ||
          (task.description?.toLowerCase().contains(lowerQuery) ?? false) ||
          (task.category?.toLowerCase().contains(lowerQuery) ?? false) ||
          (task.tags?.any((t) => t.toLowerCase().contains(lowerQuery)) ?? false);
    }).toList();
  }

  /// 清空所有任务
  Future<void> clear() async {
    await _taskBox.clear();
  }

  /// 获取统计信息
  Map<String, int> getStatistics() {
    final tasks = _taskBox.values.toList();
    return {
      'total': tasks.length,
      'pending': tasks.where((t) => t.status == TaskStatus.pending).length,
      'inProgress': tasks.where((t) => t.status == TaskStatus.inProgress).length,
      'completed': tasks.where((t) => t.status == TaskStatus.completed).length,
      'overdue': tasks.where((t) => t.isOverdue).length,
    };
  }
}

/// 任务服务 Provider
final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService();
});

/// 任务筛选类型
enum TaskFilter {
  all,
  pending,
  completed,
  overdue,
}

/// 任务列表状态
class TaskListState {
  final List<Task> tasks;
  final TaskFilter filter;
  final String? selectedCategory;
  final bool isLoading;
  final String? error;

  TaskListState({
    required this.tasks,
    this.filter = TaskFilter.all,
    this.selectedCategory,
    this.isLoading = false,
    this.error,
  });

  TaskListState copyWith({
    List<Task>? tasks,
    TaskFilter? filter,
    String? selectedCategory,
    bool? isLoading,
    String? error,
  }) {
    return TaskListState(
      tasks: tasks ?? this.tasks,
      filter: filter ?? this.filter,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 任务列表控制器
class TaskListNotifier extends StateNotifier<TaskListState> {
  final TaskService _service;

  TaskListNotifier(this._service) : super(TaskListState(tasks: [])) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.initialize();
      await loadTasks();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载任务
  Future<void> loadTasks() async {
    List<Task> tasks;
    switch (state.filter) {
      case TaskFilter.all:
        tasks = _service.getAll();
        break;
      case TaskFilter.pending:
        tasks = _service.getPending();
        break;
      case TaskFilter.completed:
        tasks = _service.getCompleted();
        break;
      case TaskFilter.overdue:
        tasks = _service.getOverdue();
        break;
    }
    
    if (state.selectedCategory != null) {
      tasks = tasks.where((t) => t.category == state.selectedCategory).toList();
    }
    
    state = state.copyWith(tasks: tasks, isLoading: false);
  }

  /// 设置筛选器
  Future<void> setFilter(TaskFilter filter) async {
    state = state.copyWith(filter: filter);
    await loadTasks();
  }

  /// 设置分类筛选
  Future<void> setCategory(String? category) async {
    state = state.copyWith(selectedCategory: category);
    await loadTasks();
  }

  /// 创建任务
  Future<Task> createTask({
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    String? category,
    DateTime? dueDate,
  }) async {
    final task = await _service.create(
      title: title,
      description: description,
      priority: priority,
      category: category,
      dueDate: dueDate,
    );
    await loadTasks();
    return task;
  }

  /// 更新任务
  Future<void> updateTask(Task task) async {
    await _service.update(task);
    await loadTasks();
  }

  /// 删除任务
  Future<void> deleteTask(String id) async {
    await _service.delete(id);
    await loadTasks();
  }

  /// 切换完成状态
  Future<void> toggleComplete(String id) async {
    await _service.toggleComplete(id);
    await loadTasks();
  }

  /// 刷新
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await loadTasks();
  }
}

/// 任务列表 Provider
final taskListProvider = StateNotifierProvider<TaskListNotifier, TaskListState>((ref) {
  final service = ref.watch(taskServiceProvider);
  return TaskListNotifier(service);
});
