import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moss/core/llm/llm_provider.dart';
import 'package:moss/core/llm/models/message.dart';
import 'package:moss/core/llm/models/tool.dart';

import '../../helpers/mock_providers.dart';

void main() {
  late MockLLMProvider mockProvider;

  setUpAll(() {
    setUpMocks();
  });

  setUp(() {
    mockProvider = MockLLMProvider();
  });

  group('LLMProvider', () {
    group('chat', () {
      test('should return response with content', () async {
        // Arrange
        final messages = [Message.user('Hello')];
        final expectedResponse = createMockLLMResponse(content: 'Hi there!');

        when(() => mockProvider.chat(any())).thenAnswer((_) async => expectedResponse);

        // Act
        final response = await mockProvider.chat(messages);

        // Assert
        expect(response.message.content, 'Hi there!');
        expect(response.message.role, MessageRole.assistant);
        expect(response.hasToolCalls, false);
        verify(() => mockProvider.chat(any())).called(1);
      });

      test('should return response with tool calls', () async {
        // Arrange
        final messages = [Message.user('Open WeChat')];
        final expectedResponse = createMockToolCallResponse(
          toolName: 'open_app',
          arguments: {'app_name': 'wechat'},
        );

        when(() => mockProvider.chat(any())).thenAnswer((_) async => expectedResponse);

        // Act
        final response = await mockProvider.chat(messages);

        // Assert
        expect(response.hasToolCalls, true);
        expect(response.message.toolCalls!.length, 1);
        expect(response.message.toolCalls!.first.name, 'open_app');
        expect(response.message.toolCalls!.first.arguments['app_name'], 'wechat');
      });

      test('should handle chat with tools parameter', () async {
        // Arrange
        final messages = [Message.user('Create a schedule')];
        final tools = [
          Tool(
            name: 'create_schedule',
            description: 'Create a new schedule',
            parameters: {},
          ),
        ];
        final expectedResponse = createMockLLMResponse(content: 'Schedule created!');

        when(() => mockProvider.chat(any(), tools: any(named: 'tools')))
            .thenAnswer((_) async => expectedResponse);

        // Act
        final response = await mockProvider.chat(messages, tools: tools);

        // Assert
        expect(response.message.content, 'Schedule created!');
        verify(() => mockProvider.chat(any(), tools: any(named: 'tools'))).called(1);
      });
    });

    group('streamChat', () {
      test('should return stream of content chunks', () async {
        // Arrange
        final messages = [Message.user('Hello')];
        final chunks = ['Hello', ' ', 'World', '!'];

        when(() => mockProvider.streamChat(any()))
            .thenAnswer((_) => Stream.fromIterable(chunks));

        // Act
        final stream = mockProvider.streamChat(messages);
        final result = await stream.toList();

        // Assert
        expect(result, chunks);
        expect(result.join(), 'Hello World!');
      });

      test('should handle empty stream', () async {
        // Arrange
        final messages = [Message.user('Hello')];

        when(() => mockProvider.streamChat(any()))
            .thenAnswer((_) => const Stream.empty());

        // Act
        final stream = mockProvider.streamChat(messages);
        final result = await stream.toList();

        // Assert
        expect(result, isEmpty);
      });
    });

    group('testConnection', () {
      test('should return true when connection is successful', () async {
        // Arrange
        when(() => mockProvider.testConnection()).thenAnswer((_) async => true);

        // Act
        final result = await mockProvider.testConnection();

        // Assert
        expect(result, true);
      });

      test('should return false when connection fails', () async {
        // Arrange
        when(() => mockProvider.testConnection()).thenAnswer((_) async => false);

        // Act
        final result = await mockProvider.testConnection();

        // Assert
        expect(result, false);
      });
    });

    group('configuration', () {
      test('should report isConfigured status', () {
        // Arrange
        when(() => mockProvider.isConfigured).thenReturn(true);

        // Act & Assert
        expect(mockProvider.isConfigured, true);
      });

      test('should set API key', () {
        // Arrange
        when(() => mockProvider.setApiKey(any())).thenReturn(null);

        // Act
        mockProvider.setApiKey('test-api-key');

        // Assert
        verify(() => mockProvider.setApiKey('test-api-key')).called(1);
      });

      test('should return available models', () {
        // Arrange
        final models = ['model-a', 'model-b', 'model-c'];
        when(() => mockProvider.availableModels).thenReturn(models);

        // Act & Assert
        expect(mockProvider.availableModels, models);
        expect(mockProvider.availableModels.length, 3);
      });

      test('should get and set current model', () {
        // Arrange
        when(() => mockProvider.currentModel).thenReturn('model-a');

        // Act & Assert
        expect(mockProvider.currentModel, 'model-a');
      });
    });
  });

  group('Message', () {
    test('should create user message', () {
      final message = Message.user('Hello');

      expect(message.role, MessageRole.user);
      expect(message.content, 'Hello');
      expect(message.toolCalls, isNull);
    });

    test('should create assistant message', () {
      final message = Message.assistant('Hi there!');

      expect(message.role, MessageRole.assistant);
      expect(message.content, 'Hi there!');
    });

    test('should create system message', () {
      final message = Message.system('You are a helpful assistant.');

      expect(message.role, MessageRole.system);
      expect(message.content, 'You are a helpful assistant.');
    });

    test('should create tool message', () {
      final message = Message.tool(
        'Tool result',
        toolCallId: 'call_123',
        name: 'test_tool',
      );

      expect(message.role, MessageRole.tool);
      expect(message.content, 'Tool result');
      expect(message.toolCallId, 'call_123');
      expect(message.name, 'test_tool');
    });

    test('should convert to JSON', () {
      final message = Message.user('Hello');
      final json = message.toJson();

      expect(json['role'], 'user');
      expect(json['content'], 'Hello');
    });

    test('should create from JSON', () {
      final json = {
        'role': 'assistant',
        'content': 'Hi there!',
      };
      final message = Message.fromJson(json);

      expect(message.role, MessageRole.assistant);
      expect(message.content, 'Hi there!');
    });

    test('should handle tool calls in JSON', () {
      final json = {
        'role': 'assistant',
        'content': '',
        'tool_calls': [
          {
            'id': 'call_123',
            'type': 'function',
            'function': {
              'name': 'test_tool',
              'arguments': {'param': 'value'},
            },
          },
        ],
      };
      final message = Message.fromJson(json);

      expect(message.toolCalls, isNotNull);
      expect(message.toolCalls!.length, 1);
      expect(message.toolCalls!.first.name, 'test_tool');
    });

    test('should copy with new values', () {
      final original = Message.user('Original');
      final copied = original.copyWith(content: 'Modified');

      expect(original.content, 'Original');
      expect(copied.content, 'Modified');
      expect(copied.role, MessageRole.user);
    });
  });

  group('ToolCall', () {
    test('should create ToolCall', () {
      final toolCall = ToolCall(
        id: 'call_123',
        name: 'test_tool',
        arguments: {'key': 'value'},
      );

      expect(toolCall.id, 'call_123');
      expect(toolCall.name, 'test_tool');
      expect(toolCall.arguments['key'], 'value');
    });

    test('should convert to JSON', () {
      final toolCall = ToolCall(
        id: 'call_123',
        name: 'test_tool',
        arguments: {'key': 'value'},
      );
      final json = toolCall.toJson();

      expect(json['id'], 'call_123');
      expect(json['type'], 'function');
      expect(json['function']['name'], 'test_tool');
      expect(json['function']['arguments']['key'], 'value');
    });

    test('should create from JSON', () {
      final json = {
        'id': 'call_456',
        'type': 'function',
        'function': {
          'name': 'another_tool',
          'arguments': {'param': 123},
        },
      };
      final toolCall = ToolCall.fromJson(json);

      expect(toolCall.id, 'call_456');
      expect(toolCall.name, 'another_tool');
      expect(toolCall.arguments['param'], 123);
    });
  });

  group('LLMResponse', () {
    test('should detect tool calls', () {
      final responseWithTools = createMockToolCallResponse(
        toolName: 'test',
        arguments: {},
      );
      final responseWithoutTools = createMockLLMResponse(content: 'Hello');

      expect(responseWithTools.hasToolCalls, true);
      expect(responseWithoutTools.hasToolCalls, false);
    });

    test('should contain token counts', () {
      final response = createMockLLMResponse(
        promptTokens: 50,
        completionTokens: 100,
      );

      expect(response.promptTokens, 50);
      expect(response.completionTokens, 100);
    });
  });
}
