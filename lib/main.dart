import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'core/services/schedule_service.dart';
import 'core/services/task_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_service.dart';
import 'core/services/api_client.dart';
import 'core/services/websocket_service.dart';
import 'core/services/dev_todo_service.dart';
import 'core/services/context_compressor.dart';
import 'core/storage/local_storage.dart';
import 'core/tools/builtin_tools.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 设置系统 UI 样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );
  
  // 初始化 Hive 本地存储
  await Hive.initFlutter();
  
  // 初始化日期格式化 (中文)
  await initializeDateFormatting('zh_CN', null);
  
  // 初始化本地存储
  final localStorage = LocalStorage();
  await localStorage.initialize();
  
  // 初始化日程服务
  final scheduleService = ScheduleService();
  await scheduleService.initialize();
  setScheduleService(scheduleService);
  
  // 初始化任务服务
  final taskService = TaskService();
  await taskService.initialize();
  setTaskService(taskService);
  
  // 初始化 DevTodo 服务 (Phase 4.1)
  final devTodoService = DevTodoService();
  await devTodoService.initialize();
  setDevTodoServiceForTools(devTodoService);
  
  // 初始化上下文压缩器 (Phase 4.2)
  final contextCompressor = ContextCompressor();
  await contextCompressor.initialize();
  
  // 初始化通知服务
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  
  // 初始化后台服务
  final backgroundService = BackgroundService();
  await backgroundService.initialize();
  await backgroundService.registerDailyReminder();
  
  // 初始化 API 客户端
  final apiClient = ApiClient();
  await apiClient.initialize();
  
  // 初始化 WebSocket 服务
  final webSocketService = WebSocketService();
  await webSocketService.initialize(localStorage);
  
  // 如果已配置服务器，自动连接 WebSocket
  if (apiClient.isConfigured) {
    webSocketService.connect();
  }
  
  // 初始化内置工具
  BuiltinTools.initialize();
  
  runApp(
    const ProviderScope(
      child: MossApp(),
    ),
  );
}
