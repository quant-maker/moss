import 'dart:async';
import '../llm/models/tool.dart';

/// 工具执行结果
class ToolResult {
  final bool success;
  final String output;
  final dynamic data;

  ToolResult({
    required this.success,
    required this.output,
    this.data,
  });

  factory ToolResult.success(String output, {dynamic data}) {
    return ToolResult(success: true, output: output, data: data);
  }

  factory ToolResult.error(String message) {
    return ToolResult(success: false, output: message);
  }
}

/// 工具处理函数类型
typedef ToolHandler = Future<ToolResult> Function(Map<String, dynamic> arguments);

/// 注册的工具项
class RegisteredTool {
  final Tool definition;
  final ToolHandler handler;

  RegisteredTool({
    required this.definition,
    required this.handler,
  });
}

/// 工具注册表 - 管理所有可用工具
class ToolRegistry {
  final Map<String, RegisteredTool> _tools = {};
  
  /// 注册工具
  void register(Tool definition, ToolHandler handler) {
    _tools[definition.name] = RegisteredTool(
      definition: definition,
      handler: handler,
    );
  }

  /// 注销工具
  void unregister(String name) {
    _tools.remove(name);
  }

  /// 获取所有工具定义
  List<Tool> get tools => _tools.values.map((t) => t.definition).toList();

  /// 获取工具名称列表
  List<String> get toolNames => _tools.keys.toList();

  /// 检查工具是否存在
  bool has(String name) => _tools.containsKey(name);

  /// 获取工具
  RegisteredTool? get(String name) => _tools[name];

  /// 执行工具
  Future<ToolResult> execute(String name, Map<String, dynamic> arguments) async {
    final tool = _tools[name];
    if (tool == null) {
      return ToolResult.error('工具 "$name" 未找到');
    }
    
    try {
      return await tool.handler(arguments);
    } catch (e) {
      return ToolResult.error('工具执行失败: $e');
    }
  }

  /// 批量执行工具
  Future<Map<String, ToolResult>> executeBatch(
    Map<String, Map<String, dynamic>> toolCalls,
  ) async {
    final results = <String, ToolResult>{};
    
    for (final entry in toolCalls.entries) {
      results[entry.key] = await execute(entry.key, entry.value);
    }
    
    return results;
  }
}
