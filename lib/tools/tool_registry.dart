import 'base_tool.dart';

/// Registry that manages and dispatches agent tools.
/// Each instance maintains its own independent tool set — not a singleton.
class ToolRegistry {
  ToolRegistry();

  final Map<String, AgentTool> _tools = {};

  /// Register a tool
  void register(AgentTool tool) {
    _tools[tool.name] = tool;
  }

  /// Unregister a tool
  void unregister(String name) {
    _tools.remove(name);
  }

  /// Check if a tool is registered
  bool has(String name) => _tools.containsKey(name);

  /// Get a tool by name
  AgentTool? get(String name) => _tools[name];

  /// Get all registered tools
  Iterable<AgentTool> get all => _tools.values;

  /// Get all function definitions for AI model
  List<Map<String, dynamic>> get functionDefinitions =>
      _tools.values.map((t) => t.toFunctionDefinition()).toList();

  /// Execute a tool call and return the result
  Future<ToolResult> execute(ToolCall toolCall) async {
    final tool = _tools[toolCall.name];
    if (tool == null) {
      return ToolResult(
        toolName: toolCall.name,
        content: '工具 "$toolCall.name" 不存在',
        toolCallId: toolCall.id,
      );
    }

    try {
      final result = await tool.execute(toolCall.arguments);
      return ToolResult(
        toolName: toolCall.name,
        content: result,
        toolCallId: toolCall.id,
      );
    } catch (e) {
      return ToolResult(
        toolName: toolCall.name,
        content: '执行失败: $e',
        toolCallId: toolCall.id,
      );
    }
  }

}
