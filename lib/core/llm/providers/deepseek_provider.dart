import 'dart:convert';
import 'package:dio/dio.dart';
import '../llm_provider.dart';
import '../models/message.dart';
import '../models/tool.dart';

/// DeepSeek 提供商实现
class DeepSeekProvider implements LLMProvider {
  static const String _baseUrl = 'https://api.deepseek.com';
  
  final Dio _dio;
  String? _apiKey;
  String _model = 'deepseek-chat';

  DeepSeekProvider() : _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  @override
  String get name => 'deepseek';

  @override
  String get displayName => 'DeepSeek';

  @override
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  @override
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
    _dio.options.headers['Authorization'] = 'Bearer $apiKey';
  }

  @override
  List<String> get availableModels => [
    'deepseek-chat',
    'deepseek-coder',
    'deepseek-reasoner',
  ];

  @override
  String get currentModel => _model;

  @override
  set currentModel(String model) {
    if (availableModels.contains(model)) {
      _model = model;
    }
  }

  @override
  Future<LLMResponse> chat(
    List<Message> messages, {
    List<Tool>? tools,
    double? temperature,
    int? maxTokens,
  }) async {
    final body = <String, dynamic>{
      'model': _model,
      'messages': messages.map((m) => m.toJson()).toList(),
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toJson()).toList();
    }

    if (temperature != null) {
      body['temperature'] = temperature;
    }

    if (maxTokens != null) {
      body['max_tokens'] = maxTokens;
    }

    final response = await _dio.post('/chat/completions', data: body);
    final data = response.data;
    
    final choice = data['choices'][0];
    final messageData = choice['message'];
    
    List<ToolCall>? toolCalls;
    if (messageData['tool_calls'] != null) {
      toolCalls = (messageData['tool_calls'] as List).map((tc) {
        var args = tc['function']['arguments'];
        if (args is String) {
          args = jsonDecode(args);
        }
        return ToolCall(
          id: tc['id'],
          name: tc['function']['name'],
          arguments: args,
        );
      }).toList();
    }

    return LLMResponse(
      message: Message.assistant(
        messageData['content'] ?? '',
        toolCalls: toolCalls,
      ),
      finishReason: choice['finish_reason'],
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
    final body = <String, dynamic>{
      'model': _model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': true,
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toJson()).toList();
    }

    if (temperature != null) {
      body['temperature'] = temperature;
    }

    if (maxTokens != null) {
      body['max_tokens'] = maxTokens;
    }

    final response = await _dio.post<ResponseBody>(
      '/chat/completions',
      data: body,
      options: Options(responseType: ResponseType.stream),
    );

    await for (final chunk in response.data!.stream) {
      final lines = utf8.decode(chunk).split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ') && !line.contains('[DONE]')) {
          try {
            final data = jsonDecode(line.substring(6));
            final content = data['choices']?[0]?['delta']?['content'];
            if (content != null) {
              yield content;
            }
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final response = await chat([Message.user('Hi')], maxTokens: 5);
      return response.message.content.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
