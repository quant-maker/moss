import 'models/message.dart';
import 'models/tool.dart';

/// LLM 响应结果
class LLMResponse {
  final Message message;
  final String? finishReason;
  final int? promptTokens;
  final int? completionTokens;

  LLMResponse({
    required this.message,
    this.finishReason,
    this.promptTokens,
    this.completionTokens,
  });

  bool get hasToolCalls =>
      message.toolCalls != null && message.toolCalls!.isNotEmpty;
}

/// LLM 提供商抽象接口
abstract class LLMProvider {
  /// 提供商名称
  String get name;

  /// 提供商显示名称
  String get displayName;

  /// 是否已配置 (有 API Key)
  bool get isConfigured;

  /// 设置 API Key
  void setApiKey(String apiKey);

  /// 获取可用模型列表
  List<String> get availableModels;

  /// 当前使用的模型
  String get currentModel;

  /// 设置模型
  set currentModel(String model);

  /// 发送聊天请求
  Future<LLMResponse> chat(
    List<Message> messages, {
    List<Tool>? tools,
    double? temperature,
    int? maxTokens,
  });

  /// 流式聊天请求
  Stream<String> streamChat(
    List<Message> messages, {
    List<Tool>? tools,
    double? temperature,
    int? maxTokens,
  });

  /// 测试连接
  Future<bool> testConnection();
}
