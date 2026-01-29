import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'llm_provider.dart';
import 'providers/deepseek_provider.dart';
import 'providers/qwen_provider.dart';
import 'providers/glm_provider.dart';
import 'providers/copilot_provider.dart';
import 'providers/backend_proxy_provider.dart';
import 'models/message.dart';
import 'models/tool.dart';
import '../services/api_client.dart';

/// LLM 路由器 - 管理多个提供商并路由请求
class LLMRouter {
  final Map<String, LLMProvider> _providers = {};
  String _activeProviderName = 'deepseek';
  bool _useBackendLLM = false;
  BackendLLMRouter? _backendRouter;

  LLMRouter() {
    // 注册所有本地提供商
    _registerProvider(DeepSeekProvider());
    _registerProvider(QwenProvider());
    _registerProvider(GLMProvider());
    _registerProvider(CopilotProvider());
  }

  void _registerProvider(LLMProvider provider) {
    _providers[provider.name] = provider;
  }

  /// 初始化后端路由器
  void initBackendRouter(ApiClient apiClient) {
    _backendRouter = BackendLLMRouter(apiClient: apiClient);
  }

  /// 是否使用后端 LLM
  bool get useBackendLLM => _useBackendLLM;

  /// 设置是否使用后端 LLM
  set useBackendLLM(bool value) {
    _useBackendLLM = value;
  }

  /// 后端路由器是否已配置
  bool get isBackendConfigured => _backendRouter != null;

  /// 获取所有提供商
  List<LLMProvider> get providers => _providers.values.toList();

  /// 获取提供商名称列表
  List<String> get providerNames => _providers.keys.toList();

  /// 获取所有提供商名称（包括后端）
  List<String> get allProviderNames {
    final names = List<String>.from(_providers.keys);
    if (_backendRouter != null) {
      for (final backend in _backendRouter!.availableProviders) {
        names.add('backend_$backend');
      }
    }
    return names;
  }

  /// 当前活跃的提供商
  LLMProvider get activeProvider {
    if (_useBackendLLM && _backendRouter != null) {
      // 从 activeProviderName 提取后端提供商名称
      final backendName = _activeProviderName.startsWith('backend_')
          ? _activeProviderName.substring(8)
          : _activeProviderName;
      return _backendRouter!.getProvider(backendName);
    }
    return _providers[_activeProviderName] ?? _providers.values.first;
  }

  /// 当前活跃的提供商名称
  String get activeProviderName => _activeProviderName;

  /// 设置活跃的提供商
  set activeProviderName(String name) {
    // 支持本地提供商和后端提供商
    if (_providers.containsKey(name) || name.startsWith('backend_')) {
      _activeProviderName = name;
    }
  }

  /// 根据名称获取提供商
  LLMProvider? getProvider(String name) {
    if (name.startsWith('backend_') && _backendRouter != null) {
      return _backendRouter!.getProvider(name.substring(8));
    }
    return _providers[name];
  }

  /// 为提供商设置 API Key
  void setApiKey(String providerName, String apiKey) {
    _providers[providerName]?.setApiKey(apiKey);
  }

  /// 发送聊天请求到当前活跃的提供商
  Future<LLMResponse> chat(
    List<Message> messages, {
    List<Tool>? tools,
    double? temperature,
    int? maxTokens,
  }) {
    return activeProvider.chat(
      messages,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// 流式聊天请求
  Stream<String> streamChat(
    List<Message> messages, {
    List<Tool>? tools,
    double? temperature,
    int? maxTokens,
  }) {
    return activeProvider.streamChat(
      messages,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// 测试当前提供商连接
  Future<bool> testConnection() {
    return activeProvider.testConnection();
  }

  /// 检查当前提供商是否已配置
  bool get isConfigured => activeProvider.isConfigured;
}

/// LLM 路由器状态
class LLMRouterState {
  final LLMRouter router;
  final String activeProviderName;
  final Map<String, String> apiKeys;
  final bool useBackendLLM;

  LLMRouterState({
    required this.router,
    required this.activeProviderName,
    required this.apiKeys,
    this.useBackendLLM = false,
  });

  LLMRouterState copyWith({
    String? activeProviderName,
    Map<String, String>? apiKeys,
    bool? useBackendLLM,
  }) {
    return LLMRouterState(
      router: router,
      activeProviderName: activeProviderName ?? this.activeProviderName,
      apiKeys: apiKeys ?? this.apiKeys,
      useBackendLLM: useBackendLLM ?? this.useBackendLLM,
    );
  }
}

/// LLM 路由器 Notifier
class LLMRouterNotifier extends StateNotifier<LLMRouterState> {
  LLMRouterNotifier() : super(LLMRouterState(
    router: LLMRouter(),
    activeProviderName: 'deepseek',
    apiKeys: {},
  ));

  /// 初始化后端路由器
  void initBackendRouter(ApiClient apiClient) {
    state.router.initBackendRouter(apiClient);
  }

  /// 设置是否使用后端 LLM
  void setUseBackendLLM(bool value) {
    state.router.useBackendLLM = value;
    state = state.copyWith(useBackendLLM: value);
  }

  /// 是否使用后端 LLM
  bool get useBackendLLM => state.useBackendLLM;

  /// 后端是否已配置
  bool get isBackendConfigured => state.router.isBackendConfigured;

  /// 切换提供商
  void switchProvider(String providerName) {
    state.router.activeProviderName = providerName;
    state = state.copyWith(activeProviderName: providerName);
  }

  /// 设置 API Key
  void setApiKey(String providerName, String apiKey) {
    state.router.setApiKey(providerName, apiKey);
    final newApiKeys = Map<String, String>.from(state.apiKeys);
    newApiKeys[providerName] = apiKey;
    state = state.copyWith(apiKeys: newApiKeys);
  }

  /// 获取当前提供商
  LLMProvider get activeProvider => state.router.activeProvider;

  /// 获取当前提供商（别名，用于兼容）
  LLMProvider? get currentProvider => state.router.activeProvider;

  /// 获取所有提供商
  List<LLMProvider> get providers => state.router.providers;

  /// 获取所有提供商名称（包括后端）
  List<String> get allProviderNames => state.router.allProviderNames;

  /// 发送聊天请求
  Future<LLMResponse> chat(
    List<Message> messages, {
    List<Tool>? tools,
    double? temperature,
    int? maxTokens,
  }) {
    return state.router.chat(
      messages,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// 流式聊天
  Stream<String> streamChat(
    List<Message> messages, {
    List<Tool>? tools,
    double? temperature,
    int? maxTokens,
  }) {
    return state.router.streamChat(
      messages,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// 测试当前提供商连接
  Future<bool> testConnection() {
    return state.router.testConnection();
  }
}

/// 全局 LLM 路由器 Provider
final llmRouterProvider = StateNotifierProvider<LLMRouterNotifier, LLMRouterState>(
  (ref) => LLMRouterNotifier(),
);
