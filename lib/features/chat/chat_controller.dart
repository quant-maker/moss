import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/llm/llm_router.dart';
import '../../core/llm/models/message.dart';
import '../../core/storage/local_storage.dart';
import '../../core/tools/builtin_tools.dart';
import '../../core/tools/tool_registry.dart';
import '../../core/services/context_analyzer.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/dev_todo_service.dart';
import '../../core/services/context_compressor.dart';
import '../../core/models/dev_todo.dart';
import '../../core/models/conversation_memory.dart';

/// 聊天状态
class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final String currentConversationId;
  final String streamingContent;
  final ContextAnalysisResult? contextAnalysis;
  final bool showContextSuggestion;
  final List<DevTodo> activeTodos;
  final DevTodo? currentTodo;
  final ConversationMemory? memory;
  final bool isCompressing;

  ChatState({
    required this.messages,
    this.isLoading = false,
    this.error,
    required this.currentConversationId,
    this.streamingContent = '',
    this.contextAnalysis,
    this.showContextSuggestion = false,
    this.activeTodos = const [],
    this.currentTodo,
    this.memory,
    this.isCompressing = false,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    String? currentConversationId,
    String? streamingContent,
    ContextAnalysisResult? contextAnalysis,
    bool? showContextSuggestion,
    List<DevTodo>? activeTodos,
    DevTodo? currentTodo,
    bool clearCurrentTodo = false,
    ConversationMemory? memory,
    bool? isCompressing,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentConversationId: currentConversationId ?? this.currentConversationId,
      streamingContent: streamingContent ?? this.streamingContent,
      contextAnalysis: contextAnalysis ?? this.contextAnalysis,
      showContextSuggestion: showContextSuggestion ?? this.showContextSuggestion,
      activeTodos: activeTodos ?? this.activeTodos,
      currentTodo: clearCurrentTodo ? null : (currentTodo ?? this.currentTodo),
      memory: memory ?? this.memory,
      isCompressing: isCompressing ?? this.isCompressing,
    );
  }

  /// 是否有活跃的开发任务
  bool get hasActiveTodos => activeTodos.isNotEmpty;

  /// 开发任务统计
  DevTodoStats get todoStats => DevTodoStats.fromList(activeTodos);
  
  /// 是否有对话记忆
  bool get hasMemory => memory != null;
  
  /// 记忆统计
  MemoryStats? get memoryStats => memory != null ? MemoryStats.fromMemory(memory!) : null;
}

/// 聊天控制器
class ChatController extends StateNotifier<ChatState> {
  final LLMRouterNotifier _llmRouter;
  final LocalStorage _storage;
  final ToolRegistry _toolRegistry;
  final ContextAnalyzer _contextAnalyzer;
  final AnalyticsService _analyticsService;
  final DevTodoService _devTodoService;
  final ContextCompressor _contextCompressor;
  StreamSubscription<String>? _streamSubscription;

  static const _systemPrompt = '''你是 Moss，一个智能管家助手。你可以帮助用户：
- 管理日程和任务
- 打开手机应用
- 搜索信息
- 播放音乐
- 点外卖
- 回答各种问题

你还可以使用 todowrite 工具来管理复杂的多步骤任务：
- 当任务需要 3 步以上时，创建 todo 列表跟踪进度
- 同一时间只有一个任务为 in_progress
- 完成任务后立即标记为 completed
- 开始新任务时标记为 in_progress

请用简洁友好的语言回复用户。当需要执行操作时，请使用提供的工具。''';

  ChatController(
    this._llmRouter,
    this._storage,
    this._contextAnalyzer,
    this._analyticsService,
    this._devTodoService,
    this._contextCompressor,
  )   : _toolRegistry = BuiltinTools.registry,
        super(ChatState(
          messages: [],
          currentConversationId: const Uuid().v4(),
        )) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _storage.initialize();
    await _analyticsService.initialize();
    await _devTodoService.initialize();
    await _contextCompressor.initialize();
    BuiltinTools.initialize();
    
    // 记录应用打开
    _analyticsService.logAppOpened();
    
    // 加载当前对话
    final currentId = _storage.getCurrentConversationId();
    if (currentId != null) {
      final messages = _storage.getMessages(currentId);
      
      // 设置 DevTodo 会话 ID
      _devTodoService.setSessionId(currentId);
      final activeTodos = _devTodoService.getActiveBySession();
      final currentTodo = _devTodoService.getInProgress();
      
      // 加载对话记忆
      final memory = _contextCompressor.getMemory(currentId);
      
      state = state.copyWith(
        messages: messages,
        currentConversationId: currentId,
        activeTodos: activeTodos,
        currentTodo: currentTodo,
        memory: memory,
      );
    } else {
      // 创建新对话
      await _createNewConversation();
    }
  }

  /// 创建新对话
  Future<void> _createNewConversation() async {
    final id = const Uuid().v4();
    await _storage.setCurrentConversationId(id);
    await _storage.addConversation(id, '新对话');
    
    // 设置新的 DevTodo 会话
    _devTodoService.setSessionId(id);
    
    state = state.copyWith(
      messages: [],
      currentConversationId: id,
      activeTodos: [],
      clearCurrentTodo: true,
    );
  }

  /// 发送消息
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    if (state.isLoading) return;

    // 记录聊天消息活动
    _analyticsService.logChatMessage();
    
    // 分析用户输入的上下文
    final analysisResult = _contextAnalyzer.analyze(content);

    // 添加用户消息
    final userMessage = Message.user(content);
    final newMessages = [...state.messages, userMessage];
    
    state = state.copyWith(
      messages: newMessages,
      isLoading: true,
      error: null,
      streamingContent: '',
      contextAnalysis: analysisResult,
      showContextSuggestion: analysisResult.hasActionableIntent && analysisResult.hasDateTime,
    );

    // 保存消息
    await _storage.saveMessages(state.currentConversationId, newMessages);

    // 更新对话标题（使用第一条消息）
    if (newMessages.length == 1) {
      final title = content.length > 20 ? '${content.substring(0, 20)}...' : content;
      await _storage.updateConversationTitle(state.currentConversationId, title);
    }

    try {
      await _chat(newMessages);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '发送失败: $e',
      );
    }
  }
  
  /// 关闭上下文建议提示
  void dismissContextSuggestion() {
    state = state.copyWith(showContextSuggestion: false);
  }
  
  /// 获取上下文分析结果
  ContextAnalysisResult? get contextAnalysis => state.contextAnalysis;

  /// 执行聊天请求
  Future<void> _chat(List<Message> messages) async {
    // 检查是否需要压缩上下文 (Phase 4.2)
    List<Message> processedMessages = messages;
    if (_contextCompressor.needsCompression(messages)) {
      state = state.copyWith(isCompressing: true);
      debugPrint('[ChatController] Context compression needed');
      
      try {
        final provider = _llmRouter.currentProvider;
        if (provider != null) {
          final result = await _contextCompressor.compress(
            conversationId: state.currentConversationId,
            messages: messages,
            llmProvider: provider,
          );
          
          if (result.wasCompressed) {
            processedMessages = result.messages;
            state = state.copyWith(
              memory: result.memory,
              isCompressing: false,
            );
            debugPrint('[ChatController] Compressed: ${result.originalTokens} -> ${result.finalTokens} tokens');
          }
        }
      } catch (e) {
        debugPrint('[ChatController] Compression error: $e');
      }
      state = state.copyWith(isCompressing: false);
    }
    
    // 准备消息列表（包含系统提示）
    final messagesWithSystem = [
      Message.system(_systemPrompt),
      ...processedMessages,
    ];

    // 使用流式响应
    final stream = _llmRouter.streamChat(
      messagesWithSystem,
      tools: _toolRegistry.tools,
    );

    final buffer = StringBuffer();
    
    _streamSubscription = stream.listen(
      (chunk) {
        buffer.write(chunk);
        state = state.copyWith(streamingContent: buffer.toString());
      },
      onDone: () async {
        final content = buffer.toString();
        final assistantMessage = Message.assistant(content);
        
        final updatedMessages = [...state.messages, assistantMessage];
        state = state.copyWith(
          messages: updatedMessages,
          isLoading: false,
          streamingContent: '',
        );
        
        await _storage.saveMessages(state.currentConversationId, updatedMessages);
      },
      onError: (error) async {
        // 流式失败，尝试非流式请求
        try {
          final response = await _llmRouter.chat(
            messagesWithSystem,
            tools: _toolRegistry.tools,
          );
          
          // 处理工具调用
          if (response.hasToolCalls) {
            await _handleToolCalls(response.message, messages);
          } else {
            final updatedMessages = [...state.messages, response.message];
            state = state.copyWith(
              messages: updatedMessages,
              isLoading: false,
            );
            await _storage.saveMessages(state.currentConversationId, updatedMessages);
          }
        } catch (e) {
          state = state.copyWith(
            isLoading: false,
            error: '请求失败: $e',
          );
        }
      },
    );
  }

  /// 处理工具调用
  Future<void> _handleToolCalls(Message assistantMessage, List<Message> previousMessages) async {
    final toolCalls = assistantMessage.toolCalls!;
    
    // 添加助手消息（包含工具调用）
    var currentMessages = [...state.messages, assistantMessage];
    state = state.copyWith(messages: currentMessages);
    
    // 执行每个工具调用
    for (final toolCall in toolCalls) {
      final result = await _toolRegistry.execute(toolCall.name, toolCall.arguments);
      
      // 如果是 todo 相关工具，刷新 todo 状态
      if (toolCall.name == 'todowrite' || toolCall.name == 'todo_update') {
        _refreshTodoState();
      }
      
      // 添加工具结果消息
      final toolMessage = Message.tool(
        result.output,
        toolCallId: toolCall.id,
        name: toolCall.name,
      );
      currentMessages = [...currentMessages, toolMessage];
      state = state.copyWith(messages: currentMessages);
    }

    // 继续对话，让 LLM 基于工具结果生成回复
    await _chat(currentMessages);
  }

  /// 刷新 DevTodo 状态
  void _refreshTodoState() {
    final activeTodos = _devTodoService.getActiveBySession();
    final currentTodo = _devTodoService.getInProgress();
    state = state.copyWith(
      activeTodos: activeTodos,
      currentTodo: currentTodo,
    );
  }

  /// 重新生成最后一条回复
  Future<void> regenerate() async {
    if (state.isLoading) return;
    if (state.messages.isEmpty) return;

    // 移除最后一条助手消息
    final messages = [...state.messages];
    while (messages.isNotEmpty && messages.last.role != MessageRole.user) {
      messages.removeLast();
    }

    if (messages.isEmpty) return;

    state = state.copyWith(
      messages: messages,
      isLoading: true,
      error: null,
    );

    try {
      await _chat(messages);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '重新生成失败: $e',
      );
    }
  }

  /// 清空对话
  Future<void> clearConversation() async {
    await _createNewConversation();
  }

  /// 停止生成
  void stopGeneration() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    
    if (state.streamingContent.isNotEmpty) {
      final assistantMessage = Message.assistant(state.streamingContent);
      final updatedMessages = [...state.messages, assistantMessage];
      state = state.copyWith(
        messages: updatedMessages,
        isLoading: false,
        streamingContent: '',
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

/// 聊天控制器 Provider
final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  final llmRouter = ref.watch(llmRouterProvider.notifier);
  final storage = ref.watch(localStorageProvider);
  final contextAnalyzer = ref.watch(contextAnalyzerProvider);
  final analyticsService = ref.watch(analyticsServiceProvider);
  final devTodoService = ref.watch(devTodoServiceProvider);
  final contextCompressor = ref.watch(contextCompressorProvider);
  return ChatController(
    llmRouter,
    storage,
    contextAnalyzer,
    analyticsService,
    devTodoService,
    contextCompressor,
  );
});
