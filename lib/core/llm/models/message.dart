/// 消息角色枚举
enum MessageRole {
  system,
  user,
  assistant,
  tool,
}

/// 消息模型
class Message {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;
  final String? name;

  Message({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.toolCalls,
    this.toolCallId,
    this.name,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 创建用户消息
  factory Message.user(String content, {String? id}) {
    return Message(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: content,
    );
  }

  /// 创建助手消息
  factory Message.assistant(String content, {String? id, List<ToolCall>? toolCalls}) {
    return Message(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.assistant,
      content: content,
      toolCalls: toolCalls,
    );
  }

  /// 创建系统消息
  factory Message.system(String content, {String? id}) {
    return Message(
      id: id ?? 'system',
      role: MessageRole.system,
      content: content,
    );
  }

  /// 创建工具响应消息
  factory Message.tool(String content, {required String toolCallId, String? name, String? id}) {
    return Message(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.tool,
      content: content,
      toolCallId: toolCallId,
      name: name,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'role': role.name,
      'content': content,
    };
    
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      json['tool_calls'] = toolCalls!.map((t) => t.toJson()).toList();
    }
    
    if (toolCallId != null) {
      json['tool_call_id'] = toolCallId;
    }
    
    if (name != null) {
      json['name'] = name;
    }
    
    return json;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => MessageRole.user,
      ),
      content: json['content'] ?? '',
      toolCalls: json['tool_calls'] != null
          ? (json['tool_calls'] as List)
              .map((t) => ToolCall.fromJson(t))
              .toList()
          : null,
      toolCallId: json['tool_call_id'],
      name: json['name'],
    );
  }

  Message copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    List<ToolCall>? toolCalls,
    String? toolCallId,
    String? name,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolCalls: toolCalls ?? this.toolCalls,
      toolCallId: toolCallId ?? this.toolCallId,
      name: name ?? this.name,
    );
  }
}

/// 工具调用
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'function',
      'function': {
        'name': name,
        'arguments': arguments,
      },
    };
  }

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final function = json['function'] as Map<String, dynamic>? ?? {};
    var args = function['arguments'];
    
    // 处理 arguments 可能是字符串的情况
    if (args is String) {
      try {
        args = Map<String, dynamic>.from(
          args.isEmpty ? {} : (args as dynamic),
        );
      } catch (_) {
        args = <String, dynamic>{};
      }
    }
    
    return ToolCall(
      id: json['id'] ?? '',
      name: function['name'] ?? '',
      arguments: args ?? {},
    );
  }
}
