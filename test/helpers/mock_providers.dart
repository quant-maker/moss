import 'package:mocktail/mocktail.dart';
import 'package:moss/core/llm/llm_provider.dart';
import 'package:moss/core/llm/models/message.dart';
import 'package:moss/core/llm/models/tool.dart';

/// Mock LLM Provider
class MockLLMProvider extends Mock implements LLMProvider {}

/// Fake Message for Mocktail
class FakeMessage extends Fake implements Message {}

/// Fake Tool for Mocktail
class FakeTool extends Fake implements Tool {}

/// 设置 Mock 的默认注册
void setUpMocks() {
  registerFallbackValue(FakeMessage());
  registerFallbackValue(FakeTool());
  registerFallbackValue(<Message>[]);
  registerFallbackValue(<Tool>[]);
}

/// 创建模拟的 LLM 响应
LLMResponse createMockLLMResponse({
  String content = 'This is a test response.',
  List<ToolCall>? toolCalls,
  String? finishReason = 'stop',
  int? promptTokens = 10,
  int? completionTokens = 20,
}) {
  return LLMResponse(
    message: Message.assistant(content, toolCalls: toolCalls),
    finishReason: finishReason,
    promptTokens: promptTokens,
    completionTokens: completionTokens,
  );
}

/// 创建带工具调用的模拟响应
LLMResponse createMockToolCallResponse({
  required String toolName,
  required Map<String, dynamic> arguments,
  String toolCallId = 'call_123',
}) {
  return LLMResponse(
    message: Message.assistant(
      '',
      toolCalls: [
        ToolCall(
          id: toolCallId,
          name: toolName,
          arguments: arguments,
        ),
      ],
    ),
    finishReason: 'tool_calls',
  );
}
