import 'package:flutter_test/flutter_test.dart';
import 'package:moss/core/tools/tool_registry.dart';
import 'package:moss/core/llm/models/tool.dart';

void main() {
  late ToolRegistry registry;

  setUp(() {
    registry = ToolRegistry();
  });

  group('ToolRegistry', () {
    group('register/unregister', () {
      test('should register a tool', () {
        final tool = Tool(
          name: 'test_tool',
          description: 'A test tool',
          parameters: {
            'type': 'object',
            'properties': {
              'param1': {'type': 'string'},
            },
          },
        );

        registry.register(tool, (args) async => ToolResult.success('OK'));

        expect(registry.has('test_tool'), true);
        expect(registry.toolNames, contains('test_tool'));
      });

      test('should unregister a tool', () {
        final tool = Tool(
          name: 'test_tool',
          description: 'A test tool',
          parameters: {},
        );

        registry.register(tool, (args) async => ToolResult.success('OK'));
        expect(registry.has('test_tool'), true);

        registry.unregister('test_tool');
        expect(registry.has('test_tool'), false);
      });

      test('should get registered tool', () {
        final tool = Tool(
          name: 'my_tool',
          description: 'My tool',
          parameters: {},
        );

        registry.register(tool, (args) async => ToolResult.success('Result'));

        final registered = registry.get('my_tool');
        expect(registered, isNotNull);
        expect(registered!.definition.name, 'my_tool');
        expect(registered.definition.description, 'My tool');
      });

      test('should return null for unregistered tool', () {
        final registered = registry.get('nonexistent');
        expect(registered, isNull);
      });

      test('should list all tools', () {
        registry.register(
          Tool(name: 'tool1', description: 'Tool 1', parameters: {}),
          (args) async => ToolResult.success('1'),
        );
        registry.register(
          Tool(name: 'tool2', description: 'Tool 2', parameters: {}),
          (args) async => ToolResult.success('2'),
        );
        registry.register(
          Tool(name: 'tool3', description: 'Tool 3', parameters: {}),
          (args) async => ToolResult.success('3'),
        );

        expect(registry.tools.length, 3);
        expect(registry.toolNames, containsAll(['tool1', 'tool2', 'tool3']));
      });
    });

    group('execute', () {
      test('should execute tool and return success result', () async {
        final tool = Tool(
          name: 'greet',
          description: 'Greet someone',
          parameters: {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
            },
          },
        );

        registry.register(tool, (args) async {
          final name = args['name'] ?? 'World';
          return ToolResult.success('Hello, $name!');
        });

        final result = await registry.execute('greet', {'name': 'Alice'});

        expect(result.success, true);
        expect(result.output, 'Hello, Alice!');
      });

      test('should return error for unknown tool', () async {
        final result = await registry.execute('unknown_tool', {});

        expect(result.success, false);
        expect(result.output, contains('未找到'));
      });

      test('should catch and report tool execution errors', () async {
        final tool = Tool(
          name: 'failing_tool',
          description: 'A tool that fails',
          parameters: {},
        );

        registry.register(tool, (args) async {
          throw Exception('Something went wrong!');
        });

        final result = await registry.execute('failing_tool', {});

        expect(result.success, false);
        expect(result.output, contains('执行失败'));
      });

      test('should pass arguments to handler', () async {
        final tool = Tool(
          name: 'calculator',
          description: 'Add two numbers',
          parameters: {
            'type': 'object',
            'properties': {
              'a': {'type': 'number'},
              'b': {'type': 'number'},
            },
          },
        );

        registry.register(tool, (args) async {
          final a = args['a'] as int;
          final b = args['b'] as int;
          return ToolResult.success('Result: ${a + b}', data: a + b);
        });

        final result = await registry.execute('calculator', {'a': 5, 'b': 3});

        expect(result.success, true);
        expect(result.output, 'Result: 8');
        expect(result.data, 8);
      });
    });

    group('executeBatch', () {
      test('should execute multiple tools', () async {
        registry.register(
          Tool(name: 'tool_a', description: 'Tool A', parameters: {}),
          (args) async => ToolResult.success('Result A'),
        );
        registry.register(
          Tool(name: 'tool_b', description: 'Tool B', parameters: {}),
          (args) async => ToolResult.success('Result B'),
        );

        final results = await registry.executeBatch({
          'tool_a': {'param': 1},
          'tool_b': {'param': 2},
        });

        expect(results.length, 2);
        expect(results['tool_a']?.success, true);
        expect(results['tool_a']?.output, 'Result A');
        expect(results['tool_b']?.success, true);
        expect(results['tool_b']?.output, 'Result B');
      });

      test('should handle mixed success and failure', () async {
        registry.register(
          Tool(name: 'good_tool', description: 'Good', parameters: {}),
          (args) async => ToolResult.success('OK'),
        );
        registry.register(
          Tool(name: 'bad_tool', description: 'Bad', parameters: {}),
          (args) async => throw Exception('Error'),
        );

        final results = await registry.executeBatch({
          'good_tool': {},
          'bad_tool': {},
        });

        expect(results['good_tool']?.success, true);
        expect(results['bad_tool']?.success, false);
      });
    });
  });

  group('ToolResult', () {
    test('should create success result', () {
      final result = ToolResult.success('Operation completed');

      expect(result.success, true);
      expect(result.output, 'Operation completed');
    });

    test('should create success result with data', () {
      final result = ToolResult.success(
        'Data fetched',
        data: {'key': 'value'},
      );

      expect(result.success, true);
      expect(result.output, 'Data fetched');
      expect(result.data, {'key': 'value'});
    });

    test('should create error result', () {
      final result = ToolResult.error('Something went wrong');

      expect(result.success, false);
      expect(result.output, 'Something went wrong');
    });
  });

  group('Tool Model', () {
    test('should create Tool with parameters', () {
      final tool = Tool(
        name: 'search',
        description: 'Search the web',
        parameters: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Search query',
            },
          },
          'required': ['query'],
        },
      );

      expect(tool.name, 'search');
      expect(tool.description, 'Search the web');
      expect(tool.parameters['properties']['query']['type'], 'string');
    });

    test('should convert to JSON', () {
      final tool = Tool(
        name: 'example',
        description: 'An example tool',
        parameters: {'type': 'object'},
      );

      final json = tool.toJson();

      expect(json['type'], 'function');
      expect(json['function']['name'], 'example');
      expect(json['function']['description'], 'An example tool');
    });
  });
}
