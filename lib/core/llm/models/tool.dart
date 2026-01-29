/// 工具定义 - 用于 Function Calling
class Tool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const Tool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  /// 转换为 OpenAI 格式的工具定义
  Map<String, dynamic> toJson() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': parameters,
      },
    };
  }

  factory Tool.fromJson(Map<String, dynamic> json) {
    final function = json['function'] as Map<String, dynamic>? ?? json;
    return Tool(
      name: function['name'] ?? '',
      description: function['description'] ?? '',
      parameters: function['parameters'] ?? {},
    );
  }

  /// 创建简单工具的便捷方法
  factory Tool.simple({
    required String name,
    required String description,
    Map<String, ToolParameter>? properties,
    List<String>? required,
  }) {
    return Tool(
      name: name,
      description: description,
      parameters: {
        'type': 'object',
        'properties': properties?.map(
          (key, value) => MapEntry(key, value.toJson()),
        ) ?? {},
        'required': required ?? [],
      },
    );
  }
}

/// 工具参数定义
class ToolParameter {
  final String type;
  final String description;
  final List<String>? enumValues;
  final ToolParameter? items;

  const ToolParameter({
    required this.type,
    required this.description,
    this.enumValues,
    this.items,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': type,
      'description': description,
    };
    
    if (enumValues != null) {
      json['enum'] = enumValues;
    }
    
    if (items != null) {
      json['items'] = items!.toJson();
    }
    
    return json;
  }

  factory ToolParameter.string(String description, {List<String>? enumValues}) {
    return ToolParameter(
      type: 'string',
      description: description,
      enumValues: enumValues,
    );
  }

  factory ToolParameter.number(String description) {
    return ToolParameter(type: 'number', description: description);
  }

  factory ToolParameter.integer(String description) {
    return ToolParameter(type: 'integer', description: description);
  }

  factory ToolParameter.boolean(String description) {
    return ToolParameter(type: 'boolean', description: description);
  }

  factory ToolParameter.array(String description, ToolParameter items) {
    return ToolParameter(
      type: 'array',
      description: description,
      items: items,
    );
  }
}
