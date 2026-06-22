import 'dart:convert';

import '../tools/base_tool.dart';
import 'tool_registry.dart';

/// 按需发现低频/场景化工具。
///
/// 返回匹配的工具列表（含名称、描述、参数），供后续通过 [defer_execute_tool] 调用。
class ToolSearchTool extends AgentTool {
  ToolSearchTool({required this.registry});

  final ToolRegistry registry;

  @override
  String get name => 'tool_search';

  @override
  String get description =>
      '当你需要某个不常用或不确定名称/参数的工具时，先用 tool_search 搜索。'
      '传入你想做的事（如"查询AI日报"、"企业ERP查询"），返回可用延迟工具列表，'
      '然后再用 defer_execute_tool 调用目标工具。'
      '不要凭猜测调用不确定的工具。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': '你想做的事或目标工具名称关键字，如"AI日报"、"生成图片"、"企业ERP"',
          },
        },
        'required': ['query'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return '错误: 请提供 query';

    final matches = registry.searchDiscoverable(query);
    if (matches.isEmpty) {
      return '未找到与 "$query" 匹配的延迟工具。';
    }
    return jsonEncode(matches);
  }
}
