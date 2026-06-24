import '../tools/base_tool.dart';
import 'tool_registry.dart';
import 'defer_execute_tool.g.dart';

/// 执行通过 [tool_search] 发现的延迟工具。
///
/// 该工具本身常驻；被调用的目标工具来自 [registry] 的 discoverable 集合，
/// 避免低频/场景化工具长期占用默认上下文。
class DeferExecuteTool extends AgentTool {
  DeferExecuteTool({required this.registry});

  final ToolRegistry registry;

  @override
  String get name => 'defer_execute_tool';

  @override
  String get description => deferExecuteToolDescription;

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'tool_name': {
            'type': 'string',
            'description': '目标工具名称（tool_search 返回的 name）',
          },
          'arguments': {
            'type': 'object',
            'description': '目标工具所需的参数对象',
          },
        },
        'required': ['tool_name', 'arguments'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final name = args['tool_name'] as String?;
    if (name == null || name.isEmpty) {
      return '错误: 请提供 tool_name';
    }
    if (!registry.isDiscoverable(name)) {
      return '错误: "$name" 不是可延迟调用的工具（请检查是否已通过 tool_search 发现，或该工具是否需要预加载直接调用）';
    }

    final arguments = (args['arguments'] as Map?)?.cast<String, dynamic>() ?? {};
    final result = await registry.execute(ToolCall(id: '', name: name, arguments: arguments));
    return result.content;
  }
}
