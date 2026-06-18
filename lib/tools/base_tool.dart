import 'dart:convert';

/// Base class for all agent tools.
/// Each tool defines: name, description, parameters (JSON Schema), and execute logic.
abstract class AgentTool {
  /// Unique tool identifier (e.g., 'calculator', 'weather')
  String get name;

  /// Human-readable description for the AI model to understand when to use this tool
  String get description;

  /// JSON Schema of tool parameters (OpenAI function calling format)
  Map<String, dynamic> get parameters;

  /// 是否只读工具（不修改用户数据）。Agent 群中非协调者 Agent 只能使用只读工具。
  bool get readOnly => true;

  /// Execute the tool with parsed arguments
  Future<String> execute(Map<String, dynamic> args);

  /// Convert to OpenAI function calling format
  Map<String, dynamic> toFunctionDefinition() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };

  @override
  String toString() => name;
}

/// Represents a tool call request from the AI model
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    // OpenAI nests arguments under "function", other providers may put it at top level
    final func = json['function'] as Map<String, dynamic>?;
    final rawArgs = func?['arguments'] ?? json['arguments'];
    final args = rawArgs is String
        ? _tryParseJson(rawArgs)
        : (rawArgs as Map? ?? {});
    return ToolCall(
      id: json['id']?.toString() ?? '',
      name: func?['name']?.toString() ?? json['name']?.toString() ?? '',
      arguments: args.cast<String, dynamic>(),
    );
  }

  static Map<String, dynamic> _tryParseJson(String s) {
    try {
      return Map<String, dynamic>.from(
        (jsonDecode(s) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return {};
    }
  }
}

/// Result of executing a tool
class ToolResult {
  final String toolName;
  final String content;
  final String? toolCallId;

  const ToolResult({
    required this.toolName,
    required this.content,
    this.toolCallId,
  });
}
