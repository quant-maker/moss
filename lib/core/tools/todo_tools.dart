import '../llm/models/tool.dart';
import '../models/dev_todo.dart';
import '../services/dev_todo_service.dart';
import 'tool_registry.dart';

/// DevTodo 服务实例（用于工具调用）
DevTodoService? _devTodoService;

/// 设置 DevTodo 服务实例
void setDevTodoService(DevTodoService service) {
  _devTodoService = service;
}

/// Todo 工具集合
/// 参考 opencode 的 TodoWrite/TodoRead 实现
class TodoTools {
  /// 注册所有 Todo 工具
  static void register(ToolRegistry registry) {
    _registerTodoWrite(registry);
    _registerTodoRead(registry);
    _registerTodoUpdate(registry);
  }

  /// todowrite - 更新整个 todo 列表
  /// 这是核心工具，用于管理和跟踪多步骤任务
  static void _registerTodoWrite(ToolRegistry registry) {
    registry.register(
      Tool(
        name: 'todowrite',
        description: '''管理任务列表，用于跟踪复杂多步骤任务的执行进度。

使用场景：
- 复杂多步骤任务（3步以上）
- 用户提供多个任务时
- 收到新指令后立即捕获
- 完成任务后标记并添加后续任务

任务状态：
- pending: 待处理
- in_progress: 进行中（同时只能有一个）
- completed: 已完成
- cancelled: 已取消

重要规则：
- 同一时间只有一个任务为 in_progress
- 完成任务后立即标记为 completed
- 开始新任务时标记为 in_progress''',
        parameters: {
          'type': 'object',
          'properties': {
            'todos': {
              'type': 'array',
              'description': '完整的任务列表',
              'items': {
                'type': 'object',
                'properties': {
                  'id': {
                    'type': 'string',
                    'description': '任务唯一标识符',
                  },
                  'content': {
                    'type': 'string',
                    'description': '任务描述',
                  },
                  'status': {
                    'type': 'string',
                    'enum': ['pending', 'in_progress', 'completed', 'cancelled'],
                    'description': '任务状态',
                  },
                  'priority': {
                    'type': 'string',
                    'enum': ['low', 'medium', 'high'],
                    'description': '优先级',
                  },
                },
                'required': ['id', 'content', 'status', 'priority'],
              },
            },
          },
          'required': ['todos'],
        },
      ),
      (args) async {
        try {
          final todosJson = args['todos'] as List<dynamic>;
          final todosList = todosJson
              .map((t) => Map<String, dynamic>.from(t as Map))
              .toList();

          if (_devTodoService != null) {
            await _devTodoService!.initialize();
            final updatedTodos = await _devTodoService!.updateAll(todosList);

            final stats = DevTodoStats.fromList(updatedTodos);
            final activeCount = stats.active;

            return ToolResult.success(
              '$activeCount 个待办任务',
              data: {
                'todos': updatedTodos.map((t) => t.toJson()).toList(),
                'stats': {
                  'total': stats.total,
                  'pending': stats.pending,
                  'in_progress': stats.inProgress,
                  'completed': stats.completed,
                },
              },
            );
          } else {
            return ToolResult.success(
              '已更新 ${todosList.length} 个任务',
              data: {'todos': todosList},
            );
          }
        } catch (e) {
          return ToolResult.error('更新任务列表失败: $e');
        }
      },
    );
  }

  /// todoread - 读取当前 todo 列表
  static void _registerTodoRead(ToolRegistry registry) {
    registry.register(
      Tool.simple(
        name: 'todoread',
        description: '读取当前任务列表，查看所有任务的状态和进度',
        properties: {
          'include_completed': ToolParameter.boolean('是否包含已完成的任务，默认 false'),
        },
        required: [],
      ),
      (args) async {
        try {
          final includeCompleted = args['include_completed'] as bool? ?? false;

          if (_devTodoService != null) {
            await _devTodoService!.initialize();
            var todos = _devTodoService!.getBySession(null);

            if (!includeCompleted) {
              todos = todos.where((t) => t.isActive).toList();
            }

            if (todos.isEmpty) {
              return ToolResult.success(
                '暂无任务',
                data: {'todos': [], 'stats': null},
              );
            }

            final stats = DevTodoStats.fromList(todos);
            final buffer = StringBuffer();
            buffer.writeln('任务列表 (${stats.active} 个活跃):');
            for (final todo in todos) {
              buffer.writeln('${todo.statusIcon} [${todo.priorityText}] ${todo.content}');
            }

            return ToolResult.success(
              buffer.toString().trim(),
              data: {
                'todos': todos.map((t) => t.toJson()).toList(),
                'stats': {
                  'total': stats.total,
                  'pending': stats.pending,
                  'in_progress': stats.inProgress,
                  'completed': stats.completed,
                },
              },
            );
          } else {
            return ToolResult.success('暂无任务数据');
          }
        } catch (e) {
          return ToolResult.error('读取任务列表失败: $e');
        }
      },
    );
  }

  /// todo_update - 更新单个任务状态（简化操作）
  static void _registerTodoUpdate(ToolRegistry registry) {
    registry.register(
      Tool.simple(
        name: 'todo_update',
        description: '快速更新单个任务的状态',
        properties: {
          'id': ToolParameter.string('任务 ID'),
          'status': ToolParameter.string(
            '新状态',
            enumValues: ['pending', 'in_progress', 'completed', 'cancelled'],
          ),
        },
        required: ['id', 'status'],
      ),
      (args) async {
        try {
          final id = args['id'] as String;
          final statusStr = args['status'] as String;

          DevTodoStatus status;
          switch (statusStr) {
            case 'pending':
              status = DevTodoStatus.pending;
              break;
            case 'in_progress':
              status = DevTodoStatus.inProgress;
              break;
            case 'completed':
              status = DevTodoStatus.completed;
              break;
            case 'cancelled':
              status = DevTodoStatus.cancelled;
              break;
            default:
              return ToolResult.error('无效的状态: $statusStr');
          }

          if (_devTodoService != null) {
            await _devTodoService!.initialize();
            final todo = await _devTodoService!.updateStatus(id, status);

            if (todo == null) {
              return ToolResult.error('任务不存在: $id');
            }

            return ToolResult.success(
              '已更新: ${todo.content} -> ${todo.statusText}',
              data: todo.toJson(),
            );
          } else {
            return ToolResult.success('已更新任务状态');
          }
        } catch (e) {
          return ToolResult.error('更新任务状态失败: $e');
        }
      },
    );
  }
}
