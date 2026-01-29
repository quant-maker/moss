import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/task.dart';
import '../../core/services/task_service.dart';
import 'widgets/task_card.dart';
import 'task_edit_page.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(taskListProvider);
    final notifier = ref.read(taskListProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => notifier.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 筛选器
          _buildFilterBar(theme, state, notifier),
          
          const Divider(height: 1),
          
          // 任务列表
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.tasks.isEmpty
                    ? _buildEmptyState(theme, state.filter)
                    : _buildTaskList(state.tasks, notifier),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, TaskListState state, TaskListNotifier notifier) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(
            theme,
            label: '全部',
            isSelected: state.filter == TaskFilter.all,
            onSelected: () => notifier.setFilter(TaskFilter.all),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            theme,
            label: '待处理',
            isSelected: state.filter == TaskFilter.pending,
            onSelected: () => notifier.setFilter(TaskFilter.pending),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            theme,
            label: '已完成',
            isSelected: state.filter == TaskFilter.completed,
            onSelected: () => notifier.setFilter(TaskFilter.completed),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            theme,
            label: '已过期',
            isSelected: state.filter == TaskFilter.overdue,
            onSelected: () => notifier.setFilter(TaskFilter.overdue),
            color: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    ThemeData theme, {
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: color?.withOpacity(0.2) ?? theme.colorScheme.primaryContainer,
      checkmarkColor: color ?? theme.colorScheme.primary,
    );
  }

  Widget _buildEmptyState(ThemeData theme, TaskFilter filter) {
    String message;
    IconData icon;
    
    switch (filter) {
      case TaskFilter.all:
        message = '还没有任务';
        icon = Icons.task_alt;
        break;
      case TaskFilter.pending:
        message = '没有待处理的任务';
        icon = Icons.pending_actions;
        break;
      case TaskFilter.completed:
        message = '没有已完成的任务';
        icon = Icons.check_circle_outline;
        break;
      case TaskFilter.overdue:
        message = '没有过期的任务';
        icon = Icons.schedule;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮添加新任务',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks, TaskListNotifier notifier) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskCard(
          task: task,
          onTap: () => _showEditTaskDialog(context, task),
          onToggleComplete: () => notifier.toggleComplete(task.id),
          onDelete: () => _confirmDelete(context, task, notifier),
        );
      },
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TaskEditPage(),
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, Task task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskEditPage(task: task),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Task task, TaskListNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务"${task.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteTask(task.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
