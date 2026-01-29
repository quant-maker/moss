import 'package:flutter/material.dart';
import '../../../core/models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;
  final VoidCallback? onDelete;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onToggleComplete,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = task.isCompleted;
    final isOverdue = task.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 完成勾选框
              InkWell(
                onTap: onToggleComplete,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? theme.colorScheme.primary
                          : _getPriorityColor(theme),
                      width: 2,
                    ),
                    color: isCompleted
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                  ),
                  child: isCompleted
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCompleted
                                  ? theme.colorScheme.onSurface.withOpacity(0.5)
                                  : null,
                            ),
                          ),
                        ),
                        if (!isCompleted)
                          _buildPriorityBadge(theme),
                      ],
                    ),
                    
                    // 描述
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    // 底部信息
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // 分类
                        if (task.category != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.category!,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        
                        // 截止日期
                        if (task.formattedDueDate != null) ...[
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: isOverdue
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.formattedDueDate!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isOverdue
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface.withOpacity(0.5),
                              fontWeight: isOverdue ? FontWeight.bold : null,
                            ),
                          ),
                        ],
                        
                        const Spacer(),
                        
                        // 完成时间
                        if (isCompleted && task.completedAt != null)
                          Text(
                            '完成于 ${task.completedAt!.month}/${task.completedAt!.day}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary.withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 更多操作
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onTap?.call();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('编辑'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Text('删除', style: TextStyle(color: theme.colorScheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(ThemeData theme) {
    switch (task.priority) {
      case TaskPriority.low:
        return Colors.grey.shade600;
      case TaskPriority.medium:
        return Colors.blue.shade600;
      case TaskPriority.high:
        return Colors.orange.shade600;
      case TaskPriority.urgent:
        return Colors.red.shade600;
    }
  }

  Widget _buildPriorityBadge(ThemeData theme) {
    if (task.priority == TaskPriority.medium) {
      return const SizedBox.shrink();
    }
    
    final color = _getPriorityColor(theme);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        task.priorityText,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
