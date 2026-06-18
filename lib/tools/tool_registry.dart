import 'base_tool.dart';

/// Registry that manages and dispatches agent tools.
/// Each instance maintains its own independent tool set — not a singleton.
class ToolRegistry {
  ToolRegistry();

  final Map<String, AgentTool> _tools = {};

  /// 工具调用次数计数器，用于频率限制
  final Map<String, int> _callCounts = {};

  /// 同一工具连续调用超过此次数时触发提醒
  static const int maxConsecutiveCalls = 3;

  /// Register a tool
  void register(AgentTool tool) {
    _tools[tool.name] = tool;
  }

  /// Unregister a tool
  void unregister(String name) {
    _tools.remove(name);
    _callCounts.remove(name);
  }

  /// Check if a tool is registered
  bool has(String name) => _tools.containsKey(name);

  /// Get a tool by name
  AgentTool? get(String name) => _tools[name];

  /// 检查工具是否为只读
  bool isReadOnly(String name) => _tools[name]?.readOnly ?? true;

  /// Get all registered tools
  Iterable<AgentTool> get all => _tools.values;

  /// Get all function definitions for AI model
  List<Map<String, dynamic>> get functionDefinitions =>
      _tools.values.map((t) => t.toFunctionDefinition()).toList();

  /// 重置调用计数（新对话开始时调用）
  void resetCallCounts() {
    _callCounts.clear();
  }

  /// 检查是否需要频率限制提醒
  String? checkFrequencyLimit(String toolName) {
    final count = (_callCounts[toolName] ?? 0) + 1;
    _callCounts[toolName] = count;
    if (count > maxConsecutiveCalls) {
      return '你已经连续调用 $toolName 工具 ${count} 次。请基于已有信息回答，不要继续调用同一工具。';
    }
    return null;
  }

  /// Execute a tool call and return the result
  Future<ToolResult> execute(ToolCall toolCall) async {
    final tool = _tools[toolCall.name];
    if (tool == null) {
      return ToolResult(
        toolName: toolCall.name,
        content: '工具 "${toolCall.name}" 不存在',
        toolCallId: toolCall.id,
      );
    }

    // 频率限制检查
    final limitMsg = checkFrequencyLimit(toolCall.name);
    if (limitMsg != null) {
      return ToolResult(
        toolName: toolCall.name,
        content: limitMsg,
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
