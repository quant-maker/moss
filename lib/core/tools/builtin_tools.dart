import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../llm/models/tool.dart';
import '../models/task.dart';
import '../services/schedule_service.dart';
import '../services/task_service.dart';
import '../services/dev_todo_service.dart';
import 'tool_registry.dart';
import 'todo_tools.dart';

/// 日程服务实例（用于工具调用）
ScheduleService? _scheduleService;
TaskService? _taskService;

/// 设置日程服务实例
void setScheduleService(ScheduleService service) {
  _scheduleService = service;
}

/// 设置任务服务实例
void setTaskService(TaskService service) {
  _taskService = service;
}

/// 设置 DevTodo 服务实例
void setDevTodoServiceForTools(DevTodoService service) {
  setDevTodoService(service);
}

/// 内置工具集合
class BuiltinTools {
  static final ToolRegistry registry = ToolRegistry();

  /// 初始化所有内置工具
  static void initialize() {
    _registerOpenApp();
    _registerCreateSchedule();
    _registerListSchedules();
    _registerCreateTask();
    _registerListTasks();
    _registerSearch();
    _registerPlayMusic();
    _registerOrderTakeout();
    _registerOpenBrowser();
    
    // 注册 Todo 工具 (Phase 4.1)
    TodoTools.register(registry);
  }

  /// 打开应用
  static void _registerOpenApp() {
    registry.register(
      Tool.simple(
        name: 'open_app',
        description: '打开手机上的应用程序',
        properties: {
          'app_name': ToolParameter.string(
            '应用名称，如: 微信、支付宝、美团、QQ音乐',
          ),
        },
        required: ['app_name'],
      ),
      (args) async {
        final appName = args['app_name'] as String;
        
        // 常见应用包名映射
        final appPackages = {
          '微信': 'com.tencent.mm',
          '支付宝': 'com.eg.android.AlipayGphone',
          '美团': 'com.sankuai.meituan',
          '饿了么': 'me.ele',
          'QQ音乐': 'com.tencent.qqmusic',
          '网易云音乐': 'com.netease.cloudmusic',
          '抖音': 'com.ss.android.ugc.aweme',
          '淘宝': 'com.taobao.taobao',
          '京东': 'com.jingdong.app.mall',
          '高德地图': 'com.autonavi.minimap',
          '百度地图': 'com.baidu.BaiduMap',
          '微博': 'com.sina.weibo',
          'B站': 'tv.danmaku.bili',
          '哔哩哔哩': 'tv.danmaku.bili',
        };

        final packageName = appPackages[appName];
        
        if (packageName != null && !kIsWeb) {
          try {
            final uri = Uri.parse('android-app://$packageName');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
              return ToolResult.success('已打开 $appName');
            }
          } catch (e) {
            debugPrint('打开应用失败: $e');
          }
        }
        
        return ToolResult.error('无法打开应用: $appName');
      },
    );
  }

  /// 创建日程
  static void _registerCreateSchedule() {
    registry.register(
      Tool.simple(
        name: 'create_schedule',
        description: '创建日程提醒事项',
        properties: {
          'title': ToolParameter.string('日程标题'),
          'date': ToolParameter.string('日期，格式: YYYY-MM-DD'),
          'time': ToolParameter.string('时间，格式: HH:MM (可选)'),
          'end_time': ToolParameter.string('结束时间，格式: HH:MM (可选)'),
          'description': ToolParameter.string('详细描述 (可选)'),
          'location': ToolParameter.string('地点 (可选)'),
          'is_all_day': ToolParameter.boolean('是否全天事件'),
        },
        required: ['title', 'date'],
      ),
      (args) async {
        final title = args['title'] as String;
        final dateStr = args['date'] as String;
        final timeStr = args['time'] as String?;
        final endTimeStr = args['end_time'] as String?;
        final description = args['description'] as String?;
        final location = args['location'] as String?;
        final isAllDay = args['is_all_day'] as bool? ?? (timeStr == null);

        try {
          // 解析日期
          final dateParts = dateStr.split('-');
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2]);
          
          int hour = 9, minute = 0;
          if (timeStr != null && timeStr.contains(':')) {
            final timeParts = timeStr.split(':');
            hour = int.parse(timeParts[0]);
            minute = int.parse(timeParts[1]);
          }

          final startTime = DateTime(year, month, day, hour, minute);
          
          // 计算结束时间
          DateTime? endTime;
          if (endTimeStr != null && endTimeStr.contains(':')) {
            final endParts = endTimeStr.split(':');
            endTime = DateTime(year, month, day, int.parse(endParts[0]), int.parse(endParts[1]));
          }

          // 使用日程服务创建
          if (_scheduleService != null) {
            await _scheduleService!.initialize();
            
            // 检测冲突
            String conflictWarning = '';
            if (!isAllDay) {
              final conflicts = _scheduleService!.checkConflictsForNew(
                startTime: startTime,
                endTime: endTime,
                isAllDay: isAllDay,
              );
              
              if (conflicts.isNotEmpty) {
                conflictWarning = '\n⚠️ 注意: 与以下日程存在时间冲突:';
                for (final c in conflicts.take(3)) {
                  conflictWarning += '\n  - ${c.formattedTime} ${c.title}';
                }
                if (conflicts.length > 3) {
                  conflictWarning += '\n  ...还有 ${conflicts.length - 3} 个冲突';
                }
              }
            }
            
            final schedule = await _scheduleService!.create(
              title: title,
              description: description,
              startTime: startTime,
              endTime: endTime,
              isAllDay: isAllDay,
              location: location,
            );

            return ToolResult.success(
              '已创建日程: $title\n日期: $dateStr${timeStr != null ? " $timeStr" : ""}${endTimeStr != null ? "-$endTimeStr" : ""}${location != null ? "\n地点: $location" : ""}$conflictWarning',
              data: {
                ...schedule.toJson(),
                'has_conflicts': conflictWarning.isNotEmpty,
              },
            );
          } else {
            // 无服务时返回模拟结果
            return ToolResult.success(
              '已创建日程: $title\n日期: $dateStr${timeStr != null ? " $timeStr" : ""}',
              data: {
                'title': title,
                'date': dateStr,
                'time': timeStr,
                'description': description,
              },
            );
          }
        } catch (e) {
          return ToolResult.error('创建日程失败: $e');
        }
      },
    );
  }

  /// 查看日程
  static void _registerListSchedules() {
    registry.register(
      Tool.simple(
        name: 'list_schedules',
        description: '查看日程列表',
        properties: {
          'date': ToolParameter.string('日期，格式: YYYY-MM-DD，不传则为今天'),
          'days': ToolParameter.integer('查看未来几天的日程，默认1天'),
        },
        required: [],
      ),
      (args) async {
        final dateStr = args['date'] as String?;
        final days = (args['days'] as int?) ?? 1;

        try {
          DateTime date;
          if (dateStr != null) {
            final parts = dateStr.split('-');
            date = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          } else {
            date = DateTime.now();
          }

          if (_scheduleService != null) {
            await _scheduleService!.initialize();
            
            List<dynamic> schedules;
            if (days > 1) {
              schedules = _scheduleService!.getByDateRange(
                date,
                date.add(Duration(days: days)),
              );
            } else {
              schedules = _scheduleService!.getByDate(date);
            }

            if (schedules.isEmpty) {
              return ToolResult.success('${dateStr ?? "今天"}没有日程安排');
            }

            final buffer = StringBuffer();
            buffer.writeln('日程列表 (${schedules.length}项):');
            for (final s in schedules) {
              buffer.writeln('- ${s.formattedTime} ${s.title}${s.isCompleted ? " [已完成]" : ""}');
            }

            return ToolResult.success(buffer.toString());
          } else {
            return ToolResult.success('暂无日程数据');
          }
        } catch (e) {
          return ToolResult.error('查看日程失败: $e');
        }
      },
    );
  }

  /// 创建任务
  static void _registerCreateTask() {
    registry.register(
      Tool.simple(
        name: 'create_task',
        description: '创建待办任务',
        properties: {
          'title': ToolParameter.string('任务标题'),
          'description': ToolParameter.string('任务描述 (可选)'),
          'priority': ToolParameter.string(
            '优先级',
            enumValues: ['low', 'medium', 'high', 'urgent'],
          ),
          'category': ToolParameter.string('分类，如: 工作、学习、生活 (可选)'),
          'due_date': ToolParameter.string('截止日期，格式: YYYY-MM-DD (可选)'),
        },
        required: ['title'],
      ),
      (args) async {
        final title = args['title'] as String;
        final description = args['description'] as String?;
        final priorityStr = args['priority'] as String? ?? 'medium';
        final category = args['category'] as String?;
        final dueDateStr = args['due_date'] as String?;

        try {
          TaskPriority priority;
          switch (priorityStr) {
            case 'low':
              priority = TaskPriority.low;
              break;
            case 'high':
              priority = TaskPriority.high;
              break;
            case 'urgent':
              priority = TaskPriority.urgent;
              break;
            default:
              priority = TaskPriority.medium;
          }

          DateTime? dueDate;
          if (dueDateStr != null) {
            final parts = dueDateStr.split('-');
            dueDate = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }

          if (_taskService != null) {
            await _taskService!.initialize();
            final task = await _taskService!.create(
              title: title,
              description: description,
              priority: priority,
              category: category,
              dueDate: dueDate,
            );

            final buffer = StringBuffer();
            buffer.write('已创建任务: $title');
            buffer.write(' [${task.priorityText}]');
            if (dueDate != null) {
              buffer.write('\n截止: $dueDateStr');
            }
            if (category != null) {
              buffer.write('\n分类: $category');
            }

            return ToolResult.success(buffer.toString(), data: task.toJson());
          } else {
            return ToolResult.success(
              '已创建任务: $title',
              data: {'title': title, 'priority': priorityStr},
            );
          }
        } catch (e) {
          return ToolResult.error('创建任务失败: $e');
        }
      },
    );
  }

  /// 查看任务
  static void _registerListTasks() {
    registry.register(
      Tool.simple(
        name: 'list_tasks',
        description: '查看任务列表',
        properties: {
          'filter': ToolParameter.string(
            '筛选类型',
            enumValues: ['all', 'pending', 'completed', 'overdue'],
          ),
          'category': ToolParameter.string('按分类筛选 (可选)'),
        },
        required: [],
      ),
      (args) async {
        final filterStr = args['filter'] as String? ?? 'pending';
        final category = args['category'] as String?;

        try {
          if (_taskService != null) {
            await _taskService!.initialize();
            
            List<Task> tasks;
            switch (filterStr) {
              case 'all':
                tasks = _taskService!.getAll();
                break;
              case 'completed':
                tasks = _taskService!.getCompleted();
                break;
              case 'overdue':
                tasks = _taskService!.getOverdue();
                break;
              default:
                tasks = _taskService!.getPending();
            }

            if (category != null) {
              tasks = tasks.where((t) => t.category == category).toList();
            }

            if (tasks.isEmpty) {
              return ToolResult.success('没有${_getFilterName(filterStr)}任务');
            }

            final buffer = StringBuffer();
            buffer.writeln('任务列表 (${tasks.length}项):');
            for (final t in tasks) {
              buffer.write('- [${t.priorityText}] ${t.title}');
              if (t.isCompleted) buffer.write(' ✓');
              if (t.isOverdue) buffer.write(' (已过期)');
              if (t.category != null) buffer.write(' #${t.category}');
              buffer.writeln();
            }

            return ToolResult.success(buffer.toString());
          } else {
            return ToolResult.success('暂无任务数据');
          }
        } catch (e) {
          return ToolResult.error('查看任务失败: $e');
        }
      },
    );
  }

  static String _getFilterName(String filter) {
    switch (filter) {
      case 'all':
        return '';
      case 'completed':
        return '已完成的';
      case 'overdue':
        return '过期的';
      default:
        return '待处理的';
    }
  }

  /// 搜索
  static void _registerSearch() {
    registry.register(
      Tool.simple(
        name: 'search',
        description: '使用搜索引擎搜索信息',
        properties: {
          'query': ToolParameter.string('搜索关键词'),
          'engine': ToolParameter.string(
            '搜索引擎',
            enumValues: ['google', 'bing', 'baidu'],
          ),
        },
        required: ['query'],
      ),
      (args) async {
        final query = args['query'] as String;
        final engine = args['engine'] as String? ?? 'google';
        
        final encodedQuery = Uri.encodeComponent(query);
        final searchUrls = {
          'google': 'https://www.google.com/search?q=$encodedQuery',
          'bing': 'https://www.bing.com/search?q=$encodedQuery',
          'baidu': 'https://www.baidu.com/s?wd=$encodedQuery',
        };

        final url = searchUrls[engine] ?? searchUrls['google']!;
        
        try {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return ToolResult.success('已打开 $engine 搜索: $query');
          }
        } catch (e) {
          debugPrint('搜索失败: $e');
        }
        
        return ToolResult.error('搜索失败');
      },
    );
  }

  /// 播放音乐
  static void _registerPlayMusic() {
    registry.register(
      Tool.simple(
        name: 'play_music',
        description: '播放音乐',
        properties: {
          'song': ToolParameter.string('歌曲名称'),
          'artist': ToolParameter.string('歌手名称 (可选)'),
          'platform': ToolParameter.string(
            '音乐平台',
            enumValues: ['qq_music', 'netease', 'spotify'],
          ),
        },
        required: ['song'],
      ),
      (args) async {
        final song = args['song'] as String;
        final artist = args['artist'] as String?;
        final platform = args['platform'] as String? ?? 'qq_music';

        final searchQuery = artist != null ? '$song $artist' : song;
        
        // 各平台搜索链接
        final platformUrls = {
          'qq_music': 'qqmusic://qq.com/ui/search?key=${Uri.encodeComponent(searchQuery)}',
          'netease': 'orpheus://song?key=${Uri.encodeComponent(searchQuery)}',
          'spotify': 'spotify:search:${Uri.encodeComponent(searchQuery)}',
        };

        try {
          final url = platformUrls[platform] ?? platformUrls['qq_music']!;
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
            return ToolResult.success('正在播放: $searchQuery');
          }
        } catch (e) {
          debugPrint('播放音乐失败: $e');
        }

        return ToolResult.error('无法播放音乐，请确保已安装音乐应用');
      },
    );
  }

  /// 点外卖
  static void _registerOrderTakeout() {
    registry.register(
      Tool.simple(
        name: 'order_takeout',
        description: '打开外卖应用点餐',
        properties: {
          'platform': ToolParameter.string(
            '外卖平台',
            enumValues: ['meituan', 'eleme'],
          ),
          'restaurant': ToolParameter.string('餐厅名称 (可选)'),
        },
        required: [],
      ),
      (args) async {
        final platform = args['platform'] as String? ?? 'meituan';
        final restaurant = args['restaurant'] as String?;

        final platformPackages = {
          'meituan': 'com.sankuai.meituan',
          'eleme': 'me.ele',
        };

        final packageName = platformPackages[platform] ?? platformPackages['meituan']!;

        if (!kIsWeb) {
          try {
            final uri = Uri.parse('android-app://$packageName');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
              final msg = restaurant != null 
                  ? '已打开外卖应用，请搜索: $restaurant'
                  : '已打开外卖应用';
              return ToolResult.success(msg);
            }
          } catch (e) {
            debugPrint('打开外卖应用失败: $e');
          }
        }

        return ToolResult.error('无法打开外卖应用');
      },
    );
  }

  /// 打开浏览器
  static void _registerOpenBrowser() {
    registry.register(
      Tool.simple(
        name: 'open_browser',
        description: '在浏览器中打开网址或搜索内容',
        properties: {
          'url': ToolParameter.string('网址或搜索内容'),
        },
        required: ['url'],
      ),
      (args) async {
        var url = args['url'] as String;
        
        // 如果不是有效的 URL，则作为搜索处理
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          if (!url.contains('.') || url.contains(' ')) {
            // 看起来像搜索词
            url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
          } else {
            url = 'https://$url';
          }
        }

        try {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return ToolResult.success('已打开: $url');
          }
        } catch (e) {
          debugPrint('打开浏览器失败: $e');
        }

        return ToolResult.error('无法打开网页');
      },
    );
  }
}
