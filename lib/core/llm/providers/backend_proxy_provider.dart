import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/tool.dart';
import '../../services/api_client.dart';
import '../llm_provider.dart';

/// 后端代理 LLM 提供商
/// 通过自建 Go 后端服务调用 LLM
class BackendProxyProvider implements LLMProvider {
  final String _backendProvider;
  final ApiClient _apiClient;
  
  String? _model;
  String? _apiKey; // 本地不使用，但接口需要

  BackendProxyProvider({
    required String provider,
    ApiClient? apiClient,
  })  : _backendProvider = provider,
        _apiClient = apiClient ?? ApiClient();

  @override
  String get name => 'backend_$_backendProvider';

  @override
  String get displayName => '后端代理 (${_getProviderDisplayName()})';

  String _getProviderDisplayName() {
    switch (_backendProvider) {
      case 'deepseek':
        return 'DeepSeek';
      case 'qwen':
        return '通义千问';
      case 'glm':
        return '智谱GLM';
      case 'copilot':
        return 'Copilot';
      default:
        return _backendProvider;
    }
  }

  @override
  List<String> get availableModels {
    switch (_backendProvider) {
      case 'deepseek':
        return ['deepseek-chat', 'deepseek-coder'];
      case 'qwen':
        return ['qwen-turbo', 'qwen-plus', 'qwen-max'];
      case 'glm':
        return ['glm-4-flash', 'glm-4', 'glm-4-plus'];
      case 'copilot':
        return ['gpt-4o', 'gpt-4', 'gpt-3.5-turbo'];
      default:
        return [];
    }
  }

  String get defaultModel {
    switch (_backendProvider) {
      case 'deepseek':
        return 'deepseek-chat';
      case 'qwen':
        return 'qwen-turbo';
      case 'glm':
        return 'glm-4-flash';
      case 'copilot':
        return 'gpt-4o';
      default:
        return '';
    }
  }

  @override
  String get currentModel => _model ?? defaultModel;

  @override
  set currentModel(String model) {
    _model = model;
  }

  @override
  bool get isConfigured => _apiClient.isConfigured;

  @override
  void setApiKey(String apiKey) {
    // 后端代理不需要在客户端设置 API Key
    // API Key 在后端服务器配置
    _apiKey = apiKey;
  }

  @override
  Future<bool> testConnection() async {
    return await _apiClient.testConnection();
  }

  List<Map<String, dynamic>> _messagesToJson(List<Message> messages) {
    return messages.map((m) => m.toJson()).toList();
  }

  List<Map<String, dynamic>>? _toolsToJson(List<Tool>? tools) {
    if (tools == null || tools.isEmpty) return null;
    return tools.map((t) => t.toJson()).toList();
  }

  @override
  Future<LLMResponse> chat(
    List<Message> messages, {
    List<Tool>? tools,
    double? temperature,
    int? maxTokens,
  }) async {
    final response = await _apiClient.chat(
      provider: _backendProvider,
      model: _model ?? defaultModel,
      messages: _messagesToJson(messages),
      tools: _toolsToJson(tools),
    );

    if (!response.success) {
      throw Exception(response.error ?? '请求失败');
    }

    final data = response.data!;
    final messageData = data['message'] as Map<String, dynamic>;
    final message = Message.fromJson(messageData);
    
    return LLMResponse(
      message: message,
      finishReason: data['finish_reason'],
      promptTokens: data['usage']?['prompt_tokens'],
      completionTokens: data['usage']?['completion_tokens'],
    );
  }

  @override
  Stream<String> streamChat(
    List<Message> messages, {
    List<Tool>? tools,
    double? temperature,
    int? maxTokens,
  }) async* {
    await for (final chunk in _apiClient.chatStream(
      provider: _backendProvider,
      model: _model ?? defaultModel,
      messages: _messagesToJson(messages),
    )) {
      if (chunk.startsWith('[ERROR]')) {
        throw Exception(chunk.substring(7));
      }
      yield chunk;
    }
  }
}

/// 后端代理 LLM 路由器
class BackendLLMRouter {
  final ApiClient _apiClient;
  final Map<String, BackendProxyProvider> _providers = {};

  BackendLLMRouter({ApiClient? apiClient}) 
      : _apiClient = apiClient ?? ApiClient();

  /// 获取或创建提供商
  BackendProxyProvider getProvider(String name) {
    if (!_providers.containsKey(name)) {
      _providers[name] = BackendProxyProvider(
        provider: name,
        apiClient: _apiClient,
      );
    }
    return _providers[name]!;
  }

  /// 获取所有可用提供商
  List<String> get availableProviders => [
    'deepseek',
    'qwen',
    'glm',
    'copilot',
  ];

  /// 测试服务器连接
  Future<bool> testConnection() => _apiClient.testConnection();
}
