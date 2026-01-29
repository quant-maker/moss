import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'chat_controller.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';
import '../../core/services/suggestion_service.dart';
import '../../core/services/context_analyzer.dart';
import '../../core/models/dev_todo.dart';
import '../../core/llm/models/message.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 在页面初始化时刷新建议
    Future.microtask(() {
      ref.read(suggestionServiceProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    
    ref.read(chatControllerProvider.notifier).sendMessage(text);
    _inputController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final theme = Theme.of(context);
    
    // 当消息变化时滚动到底部
    ref.listen(chatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.streamingContent != next.streamingContent) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moss'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新对话',
            onPressed: () {
              ref.read(chatControllerProvider.notifier).clearConversation();
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: '日程',
            onPressed: () => context.push('/schedule'),
          ),
          IconButton(
            icon: const Icon(Icons.task_alt),
            tooltip: '任务',
            onPressed: () => context.push('/tasks'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // DevTodo 任务进度指示器 (Phase 4.1)
          if (chatState.hasActiveTodos)
            _buildTodoProgressBar(chatState, theme),
          
          // 消息列表
          Expanded(
            child: chatState.messages.isEmpty && chatState.streamingContent.isEmpty
                ? _buildWelcome(theme)
                : _buildMessageList(chatState, theme),
          ),
          
          // 错误提示
          if (chatState.error != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatState.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      ref.read(chatControllerProvider.notifier).regenerate();
                    },
                  ),
                ],
              ),
            ),
          
          // 上下文智能提示
          if (chatState.showContextSuggestion && chatState.contextAnalysis != null)
            _buildContextSuggestionBar(chatState.contextAnalysis!, theme),
          
          // 输入区域
          MessageInput(
            controller: _inputController,
            isLoading: chatState.isLoading,
            onSend: _sendMessage,
            onStop: () {
              ref.read(chatControllerProvider.notifier).stopGeneration();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(ThemeData theme) {
    final suggestionState = ref.watch(suggestionServiceProvider);
    final suggestions = suggestionState.getTopSuggestions(3);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.smart_toy_outlined,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            '你好，我是 Moss',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '你的智能管家助手',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('帮我定个日程'),
              _buildSuggestionChip('打开微信'),
              _buildSuggestionChip('搜索今日新闻'),
              _buildSuggestionChip('播放音乐'),
            ],
          ),
          
          // 智能建议卡片区域
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '智能建议',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...suggestions.map((suggestion) => _buildSuggestionCard(suggestion, theme)),
          ],
          
          // 加载状态
          if (suggestionState.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  /// 构建建议卡片
  Widget _buildSuggestionCard(Suggestion suggestion, ThemeData theme) {
    return Dismissible(
      key: Key(suggestion.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(suggestionServiceProvider.notifier).dismiss(suggestion.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.error,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _handleSuggestionTap(suggestion),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getSuggestionColor(suggestion.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getSuggestionIcon(suggestion.type),
                      color: _getSuggestionColor(suggestion.type),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          suggestion.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (suggestion.actionLabel != null)
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 获取建议图标
  IconData _getSuggestionIcon(SuggestionType type) {
    switch (type) {
      case SuggestionType.createSchedule:
        return Icons.event_available;
      case SuggestionType.createTask:
        return Icons.add_task;
      case SuggestionType.completeTask:
        return Icons.task_alt;
      case SuggestionType.takeBreak:
        return Icons.free_breakfast;
      case SuggestionType.weeklyReview:
        return Icons.assessment;
      case SuggestionType.prepareForSchedule:
        return Icons.alarm;
      case SuggestionType.adjustPriority:
        return Icons.low_priority;
      case SuggestionType.habitSuggestion:
        return Icons.psychology;
    }
  }

  /// 获取建议颜色
  Color _getSuggestionColor(SuggestionType type) {
    switch (type) {
      case SuggestionType.createSchedule:
        return Colors.blue;
      case SuggestionType.createTask:
        return Colors.green;
      case SuggestionType.completeTask:
        return Colors.orange;
      case SuggestionType.takeBreak:
        return Colors.purple;
      case SuggestionType.weeklyReview:
        return Colors.indigo;
      case SuggestionType.prepareForSchedule:
        return Colors.red;
      case SuggestionType.adjustPriority:
        return Colors.amber.shade700;
      case SuggestionType.habitSuggestion:
        return Colors.teal;
    }
  }

  /// 构建上下文智能提示栏
  Widget _buildContextSuggestionBar(ContextAnalysisResult analysis, ThemeData theme) {
    final suggestionText = analysis.suggestionText;
    if (suggestionText == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.8),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              suggestionText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 创建日程按钮
          if (analysis.hasScheduleIntent)
            TextButton.icon(
              icon: const Icon(Icons.event, size: 16),
              label: const Text('创建日程'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                ref.read(chatControllerProvider.notifier).dismissContextSuggestion();
                context.push('/schedule/new');
              },
            )
          else if (analysis.hasTaskIntent)
            TextButton.icon(
              icon: const Icon(Icons.add_task, size: 16),
              label: const Text('创建任务'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                ref.read(chatControllerProvider.notifier).dismissContextSuggestion();
                context.push('/tasks/new');
              },
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              ref.read(chatControllerProvider.notifier).dismissContextSuggestion();
            },
          ),
        ],
      ),
    );
  }

  /// 处理建议卡片点击
  void _handleSuggestionTap(Suggestion suggestion) {
    final actionData = suggestion.actionData;
    
    switch (suggestion.type) {
      case SuggestionType.createSchedule:
        context.push('/schedule/new');
        break;
      case SuggestionType.createTask:
        context.push('/tasks/new');
        break;
      case SuggestionType.completeTask:
      case SuggestionType.adjustPriority:
        if (actionData != null && actionData['taskId'] != null) {
          context.push('/tasks/edit/${actionData['taskId']}');
        } else if (actionData != null && actionData['filter'] != null) {
          context.push('/tasks');
        } else {
          context.push('/tasks');
        }
        break;
      case SuggestionType.prepareForSchedule:
        if (actionData != null && actionData['scheduleId'] != null) {
          context.push('/schedule/view/${actionData['scheduleId']}');
        } else {
          context.push('/schedule');
        }
        break;
      case SuggestionType.weeklyReview:
        // 可以跳转到统计页面（如果有的话）
        context.push('/tasks');
        break;
      case SuggestionType.takeBreak:
      case SuggestionType.habitSuggestion:
        // 这些类型暂时不需要跳转
        ref.read(suggestionServiceProvider.notifier).dismiss(suggestion.id);
        break;
    }
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _inputController.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessageList(ChatState chatState, ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: chatState.messages.length + (chatState.streamingContent.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // 流式响应消息
        if (index == chatState.messages.length && chatState.streamingContent.isNotEmpty) {
          return MessageBubble(
            content: chatState.streamingContent,
            isUser: false,
            isStreaming: true,
          );
        }
        
        final message = chatState.messages[index];
        
        // 跳过系统消息和工具消息的显示
        if (message.role == MessageRole.system) {
          return const SizedBox.shrink();
        }
        
        // 工具消息显示为特殊样式
        if (message.role == MessageRole.tool) {
          return _buildToolResult(message, theme);
        }
        
        return MessageBubble(
          content: message.content,
          isUser: message.role == MessageRole.user,
          toolCalls: message.toolCalls,
        );
      },
    );
  }

  Widget _buildToolResult(Message message, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.build_circle_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.name != null ? '[${message.name}] ${message.content}' : message.content,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 DevTodo 任务进度条 (Phase 4.1)
  Widget _buildTodoProgressBar(ChatState chatState, ThemeData theme) {
    final stats = chatState.todoStats;
    final currentTodo = chatState.currentTodo;
    final progress = stats.total > 0 
        ? stats.completed / stats.total 
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentTodo != null 
                      ? '进行中: ${currentTodo.content}'
                      : '${stats.active} 个待办任务',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${stats.completed}/${stats.total}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // 展开/收起按钮
              InkWell(
                onTap: () => _showTodoDetails(chatState.activeTodos, theme),
                borderRadius: BorderRadius.circular(12),
                child: Icon(
                  Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示 Todo 详情弹窗
  void _showTodoDetails(List<DevTodo> todos, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // 拖动指示器
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.checklist,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '任务列表',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${todos.where((t) => t.isCompleted).length}/${todos.length} 完成',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return _buildTodoItem(todo, theme);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 构建单个 Todo 项
  Widget _buildTodoItem(DevTodo todo, ThemeData theme) {
    Color statusColor;
    IconData statusIcon;
    
    switch (todo.status) {
      case DevTodoStatus.pending:
        statusColor = theme.colorScheme.outline;
        statusIcon = Icons.radio_button_unchecked;
        break;
      case DevTodoStatus.inProgress:
        statusColor = theme.colorScheme.primary;
        statusIcon = Icons.pending;
        break;
      case DevTodoStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case DevTodoStatus.cancelled:
        statusColor = theme.colorScheme.error;
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: todo.isInProgress
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: todo.isInProgress
            ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              todo.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: todo.isCompleted 
                    ? TextDecoration.lineThrough 
                    : null,
                color: todo.isCompleted
                    ? theme.colorScheme.onSurface.withOpacity(0.5)
                    : null,
              ),
            ),
          ),
          // 优先级标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getPriorityColor(todo.priority).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              todo.priorityText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: _getPriorityColor(todo.priority),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取优先级颜色
  Color _getPriorityColor(DevTodoPriority priority) {
    switch (priority) {
      case DevTodoPriority.low:
        return Colors.grey;
      case DevTodoPriority.medium:
        return Colors.blue;
      case DevTodoPriority.high:
        return Colors.orange;
    }
  }
}
