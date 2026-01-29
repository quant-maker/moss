import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import '../models/user_activity.dart';
import 'schedule_service.dart';
import 'task_service.dart';
import 'analytics_service.dart';

/// 建议类型
enum SuggestionType {
  /// 创建日程建议
  createSchedule,
  /// 创建任务建议
  createTask,
  /// 完成任务提醒
  completeTask,
  /// 休息提醒
  takeBreak,
  /// 周回顾
  weeklyReview,
  /// 日程准备
  prepareForSchedule,
  /// 优先级调整建议
  adjustPriority,
  /// 习惯养成建议
  habitSuggestion,
}

/// 建议项
class Suggestion {
  final String id;
  final SuggestionType type;
  final String title;
  final String description;
  final DateTime createdAt;
  final String? actionLabel;
  final Map<String, dynamic>? actionData;
  final int priority; // 1-10, 数字越小优先级越高
  
  Suggestion({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    DateTime? createdAt,
    this.actionLabel,
    this.actionData,
    this.priority = 5,
  }) : createdAt = createdAt ?? DateTime.now();
  
  /// 获取建议图标名称
  String get iconName {
    switch (type) {
      case SuggestionType.createSchedule:
        return 'event_available';
      case SuggestionType.createTask:
        return 'add_task';
      case SuggestionType.completeTask:
        return 'task_alt';
      case SuggestionType.takeBreak:
        return 'coffee';
      case SuggestionType.weeklyReview:
        return 'assessment';
      case SuggestionType.prepareForSchedule:
        return 'alarm';
      case SuggestionType.adjustPriority:
        return 'low_priority';
      case SuggestionType.habitSuggestion:
        return 'psychology';
    }
  }
}

/// 建议服务状态
class SuggestionServiceState {
  final List<Suggestion> suggestions;
  final bool isLoading;
  final DateTime? lastRefreshTime;
  
  SuggestionServiceState({
    this.suggestions = const [],
    this.isLoading = false,
    this.lastRefreshTime,
  });
  
  SuggestionServiceState copyWith({
    List<Suggestion>? suggestions,
    bool? isLoading,
    DateTime? lastRefreshTime,
  }) {
    return SuggestionServiceState(
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
    );
  }
  
  /// 是否有建议
  bool get hasSuggestions => suggestions.isNotEmpty;
  
  /// 获取前 N 个建议
  List<Suggestion> getTopSuggestions([int count = 3]) {
    final sorted = [...suggestions]..sort((a, b) => a.priority.compareTo(b.priority));
    return sorted.take(count).toList();
  }
}

/// 建议服务
class SuggestionService {
  final ScheduleService _scheduleService;
  final TaskService _taskService;
  final AnalyticsService _analyticsService;
  
  SuggestionService(
    this._scheduleService,
    this._taskService,
    this._analyticsService,
  );
  
  /// 生成建议
  Future<List<Suggestion>> generateSuggestions() async {
    final suggestions = <Suggestion>[];
    
    try {
      await _scheduleService.initialize();
      await _taskService.initialize();
      await _analyticsService.initialize();
      
      // 1. 基于任务状态的建议
      suggestions.addAll(await _generateTaskSuggestions());
      
      // 2. 基于日程的建议
      suggestions.addAll(await _generateScheduleSuggestions());
      
      // 3. 基于用户习惯的建议
      suggestions.addAll(await _generateHabitSuggestions());
      
      // 4. 时间相关建议
      suggestions.addAll(await _generateTimeSuggestions());
      
      // 按优先级排序
      suggestions.sort((a, b) => a.priority.compareTo(b.priority));
      
    } catch (e) {
      debugPrint('SuggestionService: 生成建议失败 - $e');
    }
    
    return suggestions;
  }
  
  /// 生成任务相关建议
  Future<List<Suggestion>> _generateTaskSuggestions() async {
    final suggestions = <Suggestion>[];
    
    // 过期任务
    final overdueTasks = _taskService.getOverdue();
    if (overdueTasks.isNotEmpty) {
      if (overdueTasks.length == 1) {
        final task = overdueTasks.first;
        suggestions.add(Suggestion(
          id: 'overdue_task_${task.id}',
          type: SuggestionType.completeTask,
          title: '有任务过期了',
          description: '"${task.title}" 已过截止日期，建议尽快处理或调整计划',
          actionLabel: '查看任务',
          actionData: {'taskId': task.id},
          priority: 2,
        ));
      } else {
        suggestions.add(Suggestion(
          id: 'overdue_tasks_${DateTime.now().millisecondsSinceEpoch}',
          type: SuggestionType.adjustPriority,
          title: '${overdueTasks.length} 个任务已过期',
          description: '建议检查这些任务，重新规划或调整优先级',
          actionLabel: '查看过期任务',
          actionData: {'filter': 'overdue'},
          priority: 1,
        ));
      }
    }
    
    // 高优先级任务积压
    final pendingTasks = _taskService.getPending();
    final highPriorityTasks = pendingTasks.where(
      (t) => t.priority == TaskPriority.high || t.priority == TaskPriority.urgent
    ).toList();
    
    if (highPriorityTasks.length >= 5) {
      suggestions.add(Suggestion(
        id: 'task_backlog_${DateTime.now().millisecondsSinceEpoch}',
        type: SuggestionType.adjustPriority,
        title: '高优先级任务较多',
        description: '有 ${highPriorityTasks.length} 个高优先级任务待处理，建议分解任务或调整优先级',
        actionLabel: '管理任务',
        priority: 3,
      ));
    }
    
    // 长期未完成的任务
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final stuckTasks = pendingTasks.where((t) => t.createdAt.isBefore(sevenDaysAgo)).toList();
    
    if (stuckTasks.isNotEmpty && stuckTasks.length <= 3) {
      for (final task in stuckTasks.take(2)) {
        suggestions.add(Suggestion(
          id: 'stuck_task_${task.id}',
          type: SuggestionType.adjustPriority,
          title: '任务长期未完成',
          description: '"${task.title}" 创建超过7天，是否需要调整计划？',
          actionLabel: '处理任务',
          actionData: {'taskId': task.id},
          priority: 5,
        ));
      }
    }
    
    return suggestions;
  }
  
  /// 生成日程相关建议
  Future<List<Suggestion>> _generateScheduleSuggestions() async {
    final suggestions = <Suggestion>[];
    
    // 即将开始的日程
    final upcomingSchedules = _scheduleService.getUpcomingInMinutes(60);
    for (final schedule in upcomingSchedules.take(2)) {
      final minutesUntil = schedule.startTime.difference(DateTime.now()).inMinutes;
      if (minutesUntil > 15) {
        suggestions.add(Suggestion(
          id: 'prepare_${schedule.id}',
          type: SuggestionType.prepareForSchedule,
          title: '准备即将开始的日程',
          description: '"${schedule.title}" 将在 $minutesUntil 分钟后开始${schedule.location != null ? '，地点: ${schedule.location}' : ''}',
          actionLabel: '查看详情',
          actionData: {'scheduleId': schedule.id},
          priority: 2,
        ));
      }
    }
    
    // 明天有重要日程
    final tomorrowSchedules = _scheduleService.getTomorrow();
    final importantTomorrow = tomorrowSchedules.where(
      (s) => s.reminderTime != ReminderTime.none && !s.isCompleted
    ).toList();
    
    if (importantTomorrow.isNotEmpty) {
      final now = DateTime.now();
      // 只在晚上8点后提醒明天的日程
      if (now.hour >= 20) {
        suggestions.add(Suggestion(
          id: 'tomorrow_schedule_${DateTime.now().millisecondsSinceEpoch}',
          type: SuggestionType.prepareForSchedule,
          title: '明天有 ${importantTomorrow.length} 个日程',
          description: importantTomorrow.take(3).map((s) => s.title).join('、'),
          actionLabel: '查看明日安排',
          priority: 4,
        ));
      }
    }
    
    return suggestions;
  }
  
  /// 生成习惯相关建议
  Future<List<Suggestion>> _generateHabitSuggestions() async {
    final suggestions = <Suggestion>[];
    
    final analytics = _analyticsService.analyze();
    
    // 周回顾建议 (周日)
    if (DateTime.now().weekday == DateTime.sunday) {
      final taskStats = analytics.taskStats;
      if (taskStats.totalCreated > 0) {
        suggestions.add(Suggestion(
          id: 'weekly_review_${DateTime.now().millisecondsSinceEpoch}',
          type: SuggestionType.weeklyReview,
          title: '本周回顾',
          description: '本周创建了 ${taskStats.totalCreated} 个任务，完成了 ${taskStats.totalCompleted} 个，完成率 ${(taskStats.completionRate * 100).toStringAsFixed(0)}%',
          actionLabel: '查看统计',
          priority: 6,
        ));
      }
    }
    
    // 根据用户习惯给出建议
    if (analytics.isEarlyBird) {
      final now = DateTime.now();
      if (now.hour >= 6 && now.hour <= 8) {
        final todaySchedules = _scheduleService.getToday();
        final todayTasks = _taskService.getDueToday();
        
        if (todaySchedules.isEmpty && todayTasks.isEmpty) {
          suggestions.add(Suggestion(
            id: 'morning_plan_${DateTime.now().millisecondsSinceEpoch}',
            type: SuggestionType.createSchedule,
            title: '规划今天的安排',
            description: '早起的你今天还没有安排，要添加一些日程或任务吗？',
            actionLabel: '添加日程',
            priority: 7,
          ));
        }
      }
    }
    
    // 任务分类建议
    if (analytics.taskStats.mostUsedCategory != null) {
      final pendingTasks = _taskService.getPending();
      final uncategorizedTasks = pendingTasks.where((t) => t.category == null).toList();
      
      if (uncategorizedTasks.length >= 3) {
        suggestions.add(Suggestion(
          id: 'categorize_tasks_${DateTime.now().millisecondsSinceEpoch}',
          type: SuggestionType.habitSuggestion,
          title: '整理任务分类',
          description: '有 ${uncategorizedTasks.length} 个任务未分类，添加分类可以更好地管理',
          priority: 8,
        ));
      }
    }
    
    return suggestions;
  }
  
  /// 生成时间相关建议
  Future<List<Suggestion>> _generateTimeSuggestions() async {
    final suggestions = <Suggestion>[];
    
    final now = DateTime.now();
    
    // 午休提醒 (12:00-13:00)
    if (now.hour == 12) {
      suggestions.add(Suggestion(
        id: 'lunch_break_${DateTime.now().millisecondsSinceEpoch}',
        type: SuggestionType.takeBreak,
        title: '午餐时间到了',
        description: '工作了一上午，记得休息和用餐',
        priority: 9,
      ));
    }
    
    // 下班提醒 (18:00-19:00)
    if (now.hour >= 18 && now.hour < 19) {
      final pendingTasks = _taskService.getPending();
      final dueTodayTasks = _taskService.getDueToday().where((t) => !t.isCompleted).toList();
      
      if (dueTodayTasks.isNotEmpty) {
        suggestions.add(Suggestion(
          id: 'end_of_day_${DateTime.now().millisecondsSinceEpoch}',
          type: SuggestionType.completeTask,
          title: '今日待办提醒',
          description: '还有 ${dueTodayTasks.length} 个任务今日到期',
          actionLabel: '查看任务',
          actionData: {'filter': 'dueToday'},
          priority: 3,
        ));
      }
    }
    
    return suggestions;
  }
}

/// 建议服务 Notifier
class SuggestionServiceNotifier extends StateNotifier<SuggestionServiceState> {
  final SuggestionService _service;
  
  SuggestionServiceNotifier(this._service) : super(SuggestionServiceState());
  
  /// 刷新建议
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final suggestions = await _service.generateSuggestions();
      state = state.copyWith(
        suggestions: suggestions,
        isLoading: false,
        lastRefreshTime: DateTime.now(),
      );
    } catch (e) {
      debugPrint('SuggestionServiceNotifier: 刷新失败 - $e');
      state = state.copyWith(isLoading: false);
    }
  }
  
  /// 移除建议
  void dismiss(String suggestionId) {
    state = state.copyWith(
      suggestions: state.suggestions.where((s) => s.id != suggestionId).toList(),
    );
  }
  
  /// 清空所有建议
  void clear() {
    state = state.copyWith(suggestions: []);
  }
}

/// 建议服务 Provider
final suggestionServiceProvider = StateNotifierProvider<SuggestionServiceNotifier, SuggestionServiceState>((ref) {
  final scheduleService = ref.watch(scheduleServiceProvider);
  final taskService = ref.watch(taskServiceProvider);
  final analyticsService = ref.watch(analyticsServiceProvider);
  
  final service = SuggestionService(scheduleService, taskService, analyticsService);
  return SuggestionServiceNotifier(service);
});
