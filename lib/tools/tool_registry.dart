import 'base_tool.dart';
import 'task_plan_tool.dart';

/// Registry that manages and dispatches agent tools.
/// Each instance maintains its own independent tool set — not a singleton.
class ToolRegistry {
  ToolRegistry();

  final Map<String, AgentTool> _tools = {};

  /// 延迟加载/按需发现的工具：不进入默认 function definitions，
  /// 需要时通过 [searchDiscoverable] 查找后由 [defer_execute_tool] 调用。
  final Map<String, AgentTool> _discoverable = {};

  /// 工具调用次数计数器，用于频率限制
  final Map<String, int> _callCounts = {};

  /// 同一工具连续调用超过此次数时触发提醒
  static const int maxConsecutiveCalls = 5;

  /// Register a tool.
  /// [discoverable] 为 true 时，该工具不会直接进入默认工具列表，
  /// 只能通过 tool_search + defer_execute_tool 按需调用。
  void register(AgentTool tool, {bool discoverable = false}) {
    if (discoverable) {
      _discoverable[tool.name] = tool;
    } else {
      _tools[tool.name] = tool;
    }
  }

  /// 注册一个延迟/按需发现工具（等价于 register(tool, discoverable: true)）。
  void registerDiscoverable(AgentTool tool) => register(tool, discoverable: true);

  /// Unregister a tool
  void unregister(String name) {
    _tools.remove(name);
    _discoverable.remove(name);
    _callCounts.remove(name);
  }

  /// Check if a tool is registered (preloaded or discoverable)
  bool has(String name) => _tools.containsKey(name) || _discoverable.containsKey(name);

  /// Check if a tool is discoverable
  bool isDiscoverable(String name) => _discoverable.containsKey(name);

  /// Get a tool by name (searches both preloaded and discoverable)
  AgentTool? get(String name) => _tools[name] ?? _discoverable[name];

  /// 检查工具是否为只读
  bool isReadOnly(String name) => get(name)?.readOnly ?? true;

  /// Get all preloaded tools
  Iterable<AgentTool> get all => _tools.values;

  /// Get all discoverable tools
  Iterable<AgentTool> get discoverable => _discoverable.values;

  /// Get function definitions for all preloaded tools
  List<Map<String, dynamic>> get functionDefinitions =>
      _tools.values.map((t) => t.toFunctionDefinition()).toList();

  /// 按关键字搜索延迟工具，返回候选列表（含名称、描述、参数）。
  List<Map<String, dynamic>> searchDiscoverable(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    final tokens = q.split(RegExp(r'[\s,，]+')).where((s) => s.isNotEmpty).toList();
    return _discoverable.values
        .where((t) {
          final name = t.name.toLowerCase();
          final desc = t.description.toLowerCase();
          if (name.contains(q) || desc.contains(q)) return true;
          return tokens.any((token) => name.contains(token) || desc.contains(token));
        })
        .map((t) => {
              'name': t.name,
              'description': t.description,
              'parameters': t.parameters,
            })
        .toList();
  }

  /// 重置调用计数（新对话开始时调用）
  void resetCallCounts() {
    _callCounts.clear();
  }

  /// 检查是否需要频率限制提醒
  String? checkFrequencyLimit(String toolName) {
    final count = (_callCounts[toolName] ?? 0) + 1;
    _callCounts[toolName] = count;
    if (count > maxConsecutiveCalls) {
      return '你已经连续调用 $toolName 工具 $count 次。请基于已有信息回答，不要继续调用同一工具。';
    }
    return null;
  }

  /// Execute a tool call and return the result
  Future<ToolResult> execute(ToolCall toolCall) async {
    final tool = get(toolCall.name);
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
