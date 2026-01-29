# 智能管家助手 (Moss) - 实施计划

## 项目概览

| 项目 | 选择 |
|------|------|
| **前端** | Flutter (Android + Web) |
| **后端** | Go |
| **存储** | 本地存储 (SQLite/Hive) |
| **LLM** | Copilot, DeepSeek, GLM, Qwen 多提供商支持 |
| **通信** | APP内置即时聊天 |
| **设备控制** | Android Intent / 系统 API |

## Phase 1: 核心对话能力

### 1.1 Flutter 项目初始化
- [x] 创建 Flutter 项目
- [x] 配置项目结构
- [x] 添加核心依赖 (dio, riverpod, hive, etc.)

**状态**: ✅ 完成  
**结果**: 
- 创建了项目目录结构 `lib/{app,core,features,shared}`
- 配置 `pubspec.yaml` 添加依赖：flutter_riverpod, dio, hive, go_router, flutter_markdown 等
- 创建 `main.dart`, `app/app.dart`, `app/routes.dart` 核心入口文件 

---

### 1.2 LLM 提供商抽象层
- [x] 定义统一 LLM 接口 (LLMProvider)
- [x] 实现 LLM 路由器 (LLMRouter)
- [x] 实现 DeepSeek 适配器
- [x] 实现 Qwen 适配器
- [x] 实现 GLM 适配器
- [x] 实现 Copilot 适配器
- [x] 定义消息模型 (Message)
- [x] 定义工具模型 (Tool)

**状态**: ✅ 完成  
**结果**:
- `llm_provider.dart` - 抽象接口定义 chat/streamChat/testConnection
- `llm_router.dart` - 多提供商路由器，支持动态切换
- `providers/deepseek_provider.dart` - DeepSeek API 实现
- `providers/qwen_provider.dart` - 通义千问 API 实现
- `providers/glm_provider.dart` - 智谱 GLM API 实现
- `providers/copilot_provider.dart` - GitHub Copilot 实现
- `models/message.dart` - 消息模型，支持 tool_calls
- `models/tool.dart` - 工具定义模型 

---

### 1.3 工具调用框架
- [x] 实现工具注册表 (ToolRegistry)
- [x] 定义内置工具接口
- [x] 实现基础工具：打开APP
- [x] 实现基础工具：创建日程
- [x] 实现基础工具：搜索
- [x] 实现基础工具：播放音乐
- [x] 实现基础工具：点外卖
- [x] 实现基础工具：打开浏览器

**状态**: ✅ 完成  
**结果**:
- `tool_registry.dart` - 工具注册表，支持注册/执行/批量执行
- `builtin_tools.dart` - 内置工具集：
  - `open_app` - 打开手机应用 (微信、支付宝、美团等)
  - `create_schedule` - 创建日程提醒
  - `search` - 搜索引擎搜索 (Google/Bing/Baidu)
  - `play_music` - 播放音乐 (QQ音乐/网易云/Spotify)
  - `order_takeout` - 点外卖 (美团/饿了么)
  - `open_browser` - 打开浏览器 

---

### 1.4 本地存储
- [x] 配置 Hive 初始化
- [x] 实现对话历史存储
- [x] 实现设置存储

**状态**: ✅ 完成  
**结果**:
- `local_storage.dart` - 统一本地存储服务：
  - 设置存储：活跃提供商、API Keys、模型选择、主题
  - 对话存储：对话列表、消息历史
  - 支持增删改查操作 

---

### 1.5 对话界面
- [x] 创建聊天页面 (ChatPage)
- [x] 实现聊天控制器 (ChatController)
- [x] 实现消息气泡组件
- [x] 实现消息输入组件
- [x] 实现流式响应显示
- [x] 集成对话历史

**状态**: ✅ 完成  
**结果**:
- `chat_page.dart` - 主聊天界面，支持欢迎页、建议提示
- `chat_controller.dart` - 聊天逻辑控制器：
  - 流式响应支持
  - 工具调用自动执行
  - 对话历史持久化
  - 重新生成、停止生成功能
- `widgets/message_bubble.dart` - 消息气泡，支持 Markdown 渲染
- `widgets/message_input.dart` - 输入组件，支持停止按钮 

---

### 1.6 设置界面
- [x] 创建设置页面
- [x] 实现 LLM 提供商切换
- [x] 实现 API Key 配置

**状态**: ✅ 完成  
**结果**:
- `settings_page.dart` - 设置界面：
  - AI 提供商选择（DeepSeek/Qwen/GLM/Copilot）
  - API Key 配置与保存
  - 模型选择下拉框
  - 清除数据功能 

---

### 1.7 应用集成
- [x] 配置路由
- [x] 创建主题样式
- [x] 集成所有模块
- [x] Android 构建配置
- [x] Web 构建配置

**状态**: ✅ 完成  
**结果**:
- `main.dart` - 应用入口，初始化 Hive 和内置工具
- `app/app.dart` - 应用配置，Material 3 主题
- `app/routes.dart` - GoRouter 路由配置
- Android 配置：
  - `AndroidManifest.xml` - 权限和应用声明
  - `build.gradle` - Gradle 构建配置
  - 资源文件 (styles, launch_background)
- Web 配置：
  - `index.html` - PWA 入口页面
  - `manifest.json` - PWA 清单 

---

## Phase 2: 功能扩展

### 2.1 日程管理模块
- [x] 创建日程数据模型 (Schedule)
- [x] 实现日程存储服务
- [x] 创建日程列表页面
- [x] 创建日程详情/编辑页面
- [x] 更新工具调用集成
- [ ] 集成本地通知提醒

**状态**: ✅ 基本完成 (通知待实现)  
**结果**:
- `core/models/schedule.dart` - 日程数据模型，支持重复、提醒
- `core/services/schedule_service.dart` - 日程存储服务
- `features/schedule/schedule_page.dart` - 日程列表页面
- `features/schedule/schedule_edit_page.dart` - 日程编辑页面
- `features/schedule/widgets/` - 日历条、日程卡片组件
- 更新 `builtin_tools.dart` - create_schedule、list_schedules 工具 

---

### 2.2 任务管理模块
- [x] 创建任务数据模型 (Task)
- [x] 实现任务存储服务
- [x] 创建任务列表页面
- [x] 支持任务分类和优先级
- [x] 更新工具调用集成

**状态**: ✅ 完成  
**结果**:
- `core/models/task.dart` - 任务数据模型，支持优先级、分类、截止日期
- `core/services/task_service.dart` - 任务存储服务，支持 CRUD、筛选、统计
- `features/tasks/tasks_page.dart` - 任务列表页面
- `features/tasks/task_edit_page.dart` - 任务编辑页面
- `features/tasks/widgets/task_card.dart` - 任务卡片组件
- 更新 `builtin_tools.dart` - create_task、list_tasks 工具
- 更新 `main.dart` - 初始化 TaskService

---

### 2.3 Android 系统集成深化
- [x] 实现系统日历集成
- [x] 实现通知服务
- [x] 优化 Intent 调用
- [x] 添加后台服务支持

**状态**: ✅ 完成  
**结果**:
- `core/services/notification_service.dart` - 本地通知服务
  - 支持即时通知和定时通知
  - 日程/任务提醒自动调度
  - Android 13+ 通知权限适配
  - Android 12+ 精确闹钟权限
- `core/services/calendar_service.dart` - 系统日历集成
  - 读写系统日历事件
  - 日程同步到系统日历
  - 从系统日历导入事件
- `core/services/background_service.dart` - 后台服务
  - WorkManager 集成
  - 每日提醒任务
  - 数据同步任务
  - 旧数据清理任务
- 更新 `AndroidManifest.xml` - 添加通知、日历、后台相关权限
- 更新 `pubspec.yaml` - 添加依赖:
  - flutter_local_notifications
  - timezone, flutter_timezone
  - device_calendar
  - workmanager
  - permission_handler

---

### 2.4 Go 后端服务
- [x] 搭建基础 HTTP 服务
- [x] 实现 LLM 代理
- [x] 实现数据同步 API
- [x] 添加 WebSocket 支持

**状态**: ✅ 完成  
**结果**:
- `server/` - Go 后端服务目录
- `server/cmd/moss-server/main.go` - 服务入口
- `server/internal/api/` - HTTP 服务器和 API 处理器
- `server/internal/config/` - 配置管理
- `server/internal/llm/` - LLM 代理
  - 支持 DeepSeek、Qwen、GLM、Copilot
  - 普通和流式聊天
- `server/internal/models/` - 数据模型
- `server/internal/storage/` - BoltDB 存储
- `server/internal/ws/` - WebSocket 实时通信
- `server/Dockerfile` - Docker 镜像
- `server/docker-compose.yml` - Docker Compose 配置
- `server/Makefile` - 构建脚本
- `server/README.md` - API 文档

---

### 2.5 Flutter 连接后端
- [x] 创建 API 客户端服务
- [x] 实现后端 LLM 代理调用
- [x] 实现数据同步服务
- [x] 实现 WebSocket 客户端
- [x] 更新设置页面添加服务器配置
- [x] 更新 main.dart 初始化服务

**状态**: ✅ 完成  
**结果**:
- `core/services/api_client.dart` - API 客户端
  - 健康检查、LLM 聊天（普通/流式）
  - 日程/任务 CRUD API
  - 数据同步 API
- `core/llm/providers/backend_proxy_provider.dart` - 后端代理 LLM 提供商
  - 通过后端服务器调用 LLM
  - 支持 DeepSeek、Qwen、GLM、Copilot
- `core/services/sync_service.dart` - 数据同步服务
  - 本地与后端数据双向同步
  - 冲突解决（以更新时间为准）
- `core/services/websocket_service.dart` - WebSocket 客户端
  - 实时消息推送
  - 自动重连机制
  - 心跳保活
- 更新 `core/llm/llm_router.dart` - 集成后端代理提供商
- 更新 `core/storage/local_storage.dart` - 添加服务器配置存储
- 更新 `features/settings/settings_page.dart` - 服务器配置 UI
  - 服务器地址配置
  - 连接测试
  - 使用后端 LLM 开关
  - 数据同步按钮
  - WebSocket 连接状态
- 更新 `main.dart` - 初始化 API 客户端和 WebSocket 服务
- 更新 `pubspec.yaml` - 添加依赖:
  - web_socket_channel
  - connectivity_plus

---

## Phase 3: 高级功能与质量提升

### 3.1 语音交互功能
- [x] 添加语音输入 (Speech-to-Text)
- [x] 添加语音输出 (Text-to-Speech)
- [x] 语音设置界面 (语速、音调、音量)
- [ ] 实现语音唤醒词检测
- [ ] 语音指令快捷操作
- [ ] 连续对话模式

**状态**: ✅ 基本完成 (唤醒词待实现)  
**结果**:
- `core/services/speech_service.dart` - 语音服务
  - SpeechToText 语音识别
  - FlutterTts 语音合成
  - SpeechStatus/TtsStatus 状态枚举
  - SpeechServiceState 和 SpeechServiceNotifier (Riverpod)
- 更新 `features/chat/widgets/message_input.dart`
  - 语音输入按钮 (带脉冲动画)
  - 音量可视化指示器
  - 实时转写文字显示
- 更新 `features/chat/widgets/message_bubble.dart`
  - AI 消息朗读按钮
  - 复制按钮
  - Markdown 清理后朗读
- 更新 `features/settings/settings_page.dart`
  - 语音识别状态显示
  - TTS 状态显示
  - 自动朗读开关
  - 语速/音调/音量滑块
  - TTS 测试按钮
- 更新 `pubspec.yaml` - 添加依赖:
  - speech_to_text
  - flutter_tts
  - audio_waveforms (可选)
- 更新 `AndroidManifest.xml` - 添加权限:
  - RECORD_AUDIO
  - BLUETOOTH

**依赖**:
- `speech_to_text` - 语音识别
- `flutter_tts` - 语音合成
- `porcupine_flutter` (可选) - 唤醒词检测

---

### 3.2 智能提醒增强
- [x] 基于上下文的智能提醒
- [x] 用户习惯学习与分析
- [x] 智能建议生成
- [x] 重要事项预警
- [x] 日程冲突检测
- [x] 每日摘要通知

**状态**: ✅ 完成  
**结果**:
- `core/services/schedule_service.dart` - 新增日程冲突检测
  - `checkConflicts()` - 检查现有日程冲突
  - `checkConflictsForNew()` - 检查新日程冲突
  - `getUpcomingInMinutes()` - 获取即将开始的日程
  - `getOverdue()` - 获取过期日程
  - `getTomorrow()` - 获取明日日程
- `features/schedule/schedule_edit_page.dart` - 冲突警告 UI
- `core/tools/builtin_tools.dart` - create_schedule 返回冲突信息
- `core/services/alert_service.dart` (新建) - 预警服务
  - `AlertType` 枚举 (6种预警类型)
  - `AlertItem` 类
  - `AlertService` 检查过期任务、紧急任务、即将开始日程等
  - `alertServiceProvider` (Riverpod)
- `core/services/background_service.dart` - 后台预警检查
  - `checkAlerts` 任务类型
  - `registerAlertCheckTask()` 每小时检查
  - `_handleDailyReminder()` 增强每日摘要
- `core/models/user_activity.dart` (新建) - 用户活动模型
  - `ActivityType` 枚举 (8种活动类型)
  - `UserActivity` Hive 模型 (typeId: 10)
  - `UserAnalytics`, `TaskCompletionStats`, `ScheduleStats`, `UserPreferences`
- `core/models/user_activity.g.dart` (新建) - Hive 适配器
- `core/services/analytics_service.dart` (新建) - 分析服务
  - 活动记录方法 (`logAppOpened`, `logChatMessage`, `logScheduleCreated` 等)
  - `analyze()` 分析方法 (活跃时段、任务统计、日程统计)
  - 30天数据保留和清理
  - `analyticsServiceProvider`, `userAnalyticsProvider`
- `core/services/suggestion_service.dart` (新建) - 建议服务
  - `SuggestionType` 枚举 (8种建议类型)
  - `Suggestion` 类
  - `SuggestionService` 生成任务/日程/习惯/时间建议
  - `suggestionServiceProvider`
- `core/services/context_analyzer.dart` (新建) - 上下文分析服务
  - `EntityType` 枚举 (日期时间、任务意图、日程意图、地点等)
  - `RecognizedEntity` 类
  - `ContextAnalysisResult` 类
  - `ContextAnalyzer` 使用正则表达式识别实体
  - 支持中文日期时间解析 (今天、明天、下周一、3点等)
  - `contextAnalyzerProvider`
- `features/chat/chat_page.dart` - 智能建议卡片
  - 欢迎页显示智能建议
  - 可滑动移除的建议卡片
  - 上下文智能提示栏
- `features/chat/chat_controller.dart` - 上下文分析集成
  - 发送消息时自动分析上下文
  - 记录用户活动到分析服务
  - 显示上下文建议提示

---

### 3.3 测试覆盖
- [x] 核心服务单元测试
- [x] LLM Provider 模拟测试
- [x] Widget 测试
- [ ] 集成测试 (可选)
- [ ] 测试覆盖率报告 (可选)

**状态**: ✅ 基本完成  
**结果**:
- `test/helpers/test_helpers.dart` - 测试辅助工具
  - `initializeTestEnvironment()` / `cleanupTestEnvironment()`
  - `createTestWidget()` / `createTestContainer()`
  - `createTestDateTime()`
- `test/helpers/mock_providers.dart` - Mock 类定义
  - `MockLLMProvider` (mocktail)
  - `FakeMessage` / `FakeTool`
  - `createMockLLMResponse()` / `createMockToolCallResponse()`
- `test/core/llm/llm_provider_test.dart` - LLM Provider 测试
  - chat / streamChat / testConnection / configuration 测试
  - Message / ToolCall / LLMResponse 测试
- `test/core/models/schedule_test.dart` - Schedule 模型测试
  - Creation / RepeatType / ReminderTime / Formatting
  - JSON Serialization / copyWith
- `test/core/models/task_test.dart` - Task 模型测试
  - Priority / Status / Due Date / Overdue detection
  - JSON Serialization / copyWith
- `test/core/services/context_analyzer_test.dart` - ContextAnalyzer 测试
  - DateTime Recognition (今天/明天/下午3点/15:30 等)
  - Task/Schedule/Reminder Intent Recognition
  - Location Recognition / Edge Cases
- `test/core/tools/tool_registry_test.dart` - ToolRegistry 测试
  - register/unregister / execute / executeBatch
  - ToolResult / Tool Model
- `test/features/chat/message_bubble_test.dart` - Widget 测试
  - User/Assistant Message 显示
  - Streaming State / Tool Calls / Action Buttons
  - 使用 MockSpeechNotifier 替代真实语音服务

**测试依赖** (pubspec.yaml):
- mockito: ^5.4.4
- mocktail: ^1.0.3
- fake_async: ^1.3.1

---

### 3.4 UI/UX 优化
- [x] 深色模式支持
- [x] 页面过渡动画
- [x] 加载状态优化
- [x] 响应式布局 (平板适配)
- [x] 主题定制功能

**状态**: ✅ 完成  
**结果**:
- `core/theme/theme_provider.dart` (新建) - 主题状态管理
  - `ThemeState` - 主题状态类 (themeMode, seedColor)
  - `ThemeNotifier` - 主题状态管理器
  - `themeProvider` - Riverpod Provider
  - `getLightTheme()` / `getDarkTheme()` - 主题生成函数
  - 10种预设主题色
- 更新 `app/app.dart` - 集成 ThemeProvider
- 更新 `app/routes.dart` - 自定义页面过渡动画
  - Chat: FadeTransition
  - Schedule/Tasks: SlideTransition (从右)
  - Settings: SlideTransition + FadeTransition (从下)
- 更新 `core/storage/local_storage.dart` - 添加 seedColor 存储
- 更新 `features/settings/settings_page.dart` - 外观设置
  - 主题模式选择 (浅色/跟随系统/深色)
  - 主题色选择 (10种预设色)
- `shared/widgets/loading_widgets.dart` (新建) - 加载状态组件
  - `LoadingIndicator` - 统一加载指示器
  - `SkeletonLoader` - 骨架屏加载
  - `MessageSkeletonLoader` / `ListItemSkeletonLoader` / `CardSkeletonLoader`
  - `EmptyState` - 空状态组件
  - `ErrorState` - 错误状态组件
  - `PulseAnimationContainer` - 脉冲动画
  - `ShimmerContainer` - Shimmer 效果
- `shared/widgets/responsive_layout.dart` (新建) - 响应式布局
  - `DeviceType` 枚举 (mobile/tablet/desktop)
  - `ResponsiveLayout` - 响应式工具类
  - `ResponsiveBuilder` / `ResponsiveWidget` - 响应式构建器
  - `CenteredContent` - 居中内容容器
  - `AdaptiveGrid` - 自适应网格
  - `AdaptiveSidebarLayout` - 侧边栏布局
  - `MasterDetailLayout` - 主从布局
  - `ScreenSizeExtension` - 屏幕尺寸扩展

---

### 3.5 构建发布准备
- [x] Android 签名配置
- [x] APK/AAB 构建脚本
- [x] 应用图标和启动屏
- [ ] 后端部署文档 (可选)
- [ ] 用户使用手册 (可选)

**状态**: ✅ 基本完成  
**结果**:
- 更新 `android/app/build.gradle`:
  - 应用 ID: `com.moss.assistant`
  - 签名配置 (从 key.properties 读取)
  - Debug/Release 构建类型
  - APK 分包配置 (arm64-v8a, armeabi-v7a, x86_64)
  - 输出文件名格式化
- `android/key.properties.template` (新建) - 签名配置模板
- `build.sh` (新建) - 构建脚本
  - clean: 清理构建缓存
  - deps: 获取依赖
  - gen: 代码生成
  - test: 运行测试
  - analyze: 代码分析
  - apk/apk-debug/apk-split: APK 构建
  - aab: App Bundle 构建
  - web: Web 构建
  - all: 完整构建流程
- 更新 `pubspec.yaml`:
  - 添加 flutter_launcher_icons 依赖
  - 添加 flutter_native_splash 依赖
  - 图标和启动屏配置
  - assets 目录配置
- `assets/icon/README.md` (新建) - 图标资源说明

---

## Phase 4: 新功能开发

### 4.1 任务插入 Pending 机制
- [x] 创建 DevTodo 数据模型
- [x] 创建 DevTodoService 服务
- [x] 创建 todowrite/todoread 工具
- [x] 在 ChatController 中集成
- [x] 在 ChatPage 显示任务进度

**状态**: ✅ 完成  
**结果**:
- `core/models/dev_todo.dart` (新建) - DevTodo 数据模型
  - `DevTodoStatus` 枚举 (pending/inProgress/completed/cancelled)
  - `DevTodoPriority` 枚举 (low/medium/high)
  - `DevTodo` Hive 模型 (typeId: 11)
  - `DevTodoStats` 统计类
- `core/models/dev_todo.g.dart` (新建) - Hive 适配器
- `core/services/dev_todo_service.dart` (新建) - DevTodo 服务
  - CRUD 操作
  - `updateAll()` - 批量更新 (opencode todowrite 风格)
  - 会话管理
  - 状态转换（同时只有一个 in_progress）
  - `DevTodoState`, `DevTodoNotifier`, `devTodoProvider`
- `core/tools/todo_tools.dart` (新建) - Todo 工具
  - `todowrite` - 管理任务列表
  - `todoread` - 读取任务列表
  - `todo_update` - 快速更新单个任务状态
- 更新 `core/tools/builtin_tools.dart` - 注册 Todo 工具
- 更新 `features/chat/chat_controller.dart` - 集成 DevTodo
  - ChatState 添加 activeTodos/currentTodo
  - 工具调用后刷新 todo 状态
- 更新 `features/chat/chat_page.dart` - 任务进度 UI
  - 进度条显示
  - 任务详情弹窗
  - 优先级颜色标识
- 更新 `main.dart` - 初始化 DevTodoService

**参考实现**: opencode/clawbot 的 TodoWrite/TodoRead 机制

---

### 4.2 无限上下文机制
- [x] 创建 ConversationMemory 模型
- [x] 创建 ContextCompressor 服务
- [x] 集成到 ChatController

**状态**: ✅ 完成  
**结果**:
- `core/models/conversation_memory.dart` (新建) - 对话记忆模型
  - `MemoryType` 枚举 (summary/conclusion/preference/decision/entity)
  - `MemoryItem` Hive 模型 (typeId: 12)
  - `ConversationMemory` Hive 模型 (typeId: 13)
  - `MemoryStats` 统计类
  - `toPromptText()` - 生成用于注入 system prompt 的记忆文本
  - `estimateTokens()` - Token 估算
  - `pruneMemories()` - 清理低重要性记忆
- `core/models/conversation_memory.g.dart` (新建) - Hive 适配器
- `core/services/context_compressor.dart` (新建) - 上下文压缩服务
  - `CompressionConfig` - 压缩配置 (maxTokens/keepRecentMessages/targetTokens)
  - `CompressionResult` - 压缩结果
  - `ContextCompressor` - 核心压缩器
    - `needsCompression()` - 检查是否需要压缩
    - `compress()` - 执行压缩
    - `_generateSummaryWithLLM()` - 使用 LLM 生成摘要和提取关键信息
    - `_simpleExtraction()` - 简单规则提取（备用方案）
  - `contextCompressorProvider`
- 更新 `features/chat/chat_controller.dart`
  - ChatState 添加 memory/isCompressing
  - `_chat()` 方法中集成压缩检查
  - 压缩时显示状态
- 更新 `main.dart` - 初始化 ContextCompressor

**核心特性**:
1. **智能压缩触发**: 当 token 数超过阈值 (默认 6000) 时自动触发
2. **LLM 辅助提取**: 使用 LLM 生成摘要并提取关键信息
3. **多类型记忆**: 支持摘要、结论、偏好、决策、实体等类型
4. **重要性排序**: 按重要性保留记忆，自动清理低重要性内容
5. **保留最近消息**: 始终保留最近 N 条原始消息
6. **记忆持久化**: 使用 Hive 存储，跨会话保留

---

## 变更日志

| 日期 | 变更内容 |
|------|----------|
| 2026-01-28 | Phase 4.2 无限上下文机制完成 (ConversationMemory/ContextCompressor/ChatController集成) |
| 2026-01-28 | Phase 4.1 任务插入Pending机制完成 (DevTodo/DevTodoService/TodoTools/UI集成) |
| 2026-01-27 | Phase 3.5 构建发布准备完成 (签名配置/构建脚本/图标配置) |
| 2026-01-27 | Phase 3.4 UI/UX 优化完成 (深色模式/动画/加载状态/响应式布局) |
| 2026-01-27 | Phase 3.3 测试覆盖完成 (8个测试文件, Mock/Helper 类) |
| 2026-01-27 | Phase 3.2 智能提醒增强完成 (日程冲突/预警/分析/建议/上下文) |
| 2026-01-27 | Phase 3.1 语音交互功能完成 (STT/TTS/设置) |
| 2026-01-27 | Phase 2.5 Flutter 连接后端完成 |
| 2026-01-27 | Phase 2.4 Go 后端服务完成 |
| 2026-01-27 | Phase 2.3 Android 系统集成完成 |
| 2026-01-27 | Phase 2.2 任务管理模块完成 |
| 2026-01-27 | Phase 1 全部完成 |
| 2026-01-27 | 1.7 应用集成完成 - Android/Web 配置 |
| 2026-01-27 | 1.6 设置界面完成 - 提供商切换、API Key 配置 |
| 2026-01-27 | 1.5 对话界面完成 - 聊天页面、消息气泡、流式响应 |
| 2026-01-27 | 1.4 本地存储完成 - Hive 存储服务 |
| 2026-01-27 | 1.3 工具调用框架完成 - 6个内置工具 |
| 2026-01-27 | 1.2 LLM 提供商抽象层完成 - 4个提供商适配器 |
| 2026-01-27 | 1.1 Flutter 项目初始化完成 |
| 2026-01-27 | 创建计划文档 |

