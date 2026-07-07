import 'dart:convert';

import '../core/service_locator.dart';
import '../services/mcp_manager.dart';
import 'base_tool.dart';

/// 把 MCP 服务器的单个工具包装成 [AgentTool]，接入 ToolRegistry。
///
/// 每个 adapter 绑定一个 serverId + tool 定义，execute 时通过
/// [McpManager.callTool] 转发到对应 MCP 服务器。
class McpToolAdapter extends AgentTool {
  final String serverId;
  final String _name;
  final String _description;
  final Map<String, dynamic> _inputSchema;

  McpToolAdapter({
    required this.serverId,
    required String name,
    required String description,
    required Map<String, dynamic> inputSchema,
  })  : _name = name,
        _description = description,
        _inputSchema = inputSchema;

  /// 工具名加 serverId 前缀，避免多个 MCP 服务器工具重名冲突。
  @override
  String get name => 'mcp_${serverId}_$_name';

  /// 原始工具名（不带前缀），用于调用 MCP 服务器。
  String get rawName => _name;

  @override
  String get description {
    final desc = _description.isEmpty ? 'MCP 工具' : _description;
    return '$desc（来自 MCP 服务器 $serverId）';
  }

  @override
  bool get readOnly => false;

  @override
  Map<String, dynamic> get parameters =>
      _inputSchema.isNotEmpty ? _inputSchema : {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final result = await getIt<McpManager>().callTool(serverId, _name, args);
      return _extractContent(result);
    } catch (e) {
      return '错误: MCP 工具 $_name 调用失败: $e';
    }
  }

  /// 从 MCP tools/call 响应中提取可读文本。
  ///
  /// MCP 协议 result 格式：
  ///   { "content": [ { "type": "text", "text": "..." }, ... ], "isError": bool }
  /// 兼容直接返回字符串或嵌套 result 的情况。
  String _extractContent(Map<String, dynamic> result) {
    // isError 标记
    final isError = result['isError'] == true;

    final content = result['content'];
    if (content is List) {
      final parts = <String>[];
      for (final item in content) {
        if (item is Map) {
          final type = item['type'];
          if (type == 'text') {
            parts.add(item['text']?.toString() ?? '');
          } else if (item['type'] == 'image' && item['data'] != null) {
            parts.add('[图片数据: ${item['mimeType'] ?? 'unknown'}]');
          } else if (item['type'] == 'resource' && item['resource'] != null) {
            final r = item['resource'] as Map;
            parts.add('[资源: ${r['uri'] ?? r['name'] ?? ''}]');
          } else {
            parts.add(item.toString());
          }
        } else {
          parts.add(item.toString());
        }
      }
      final text = parts.where((s) => s.isNotEmpty).join('\n');
      return isError && text.isNotEmpty ? '错误: $text' : text;
    }

    // 兜底：直接序列化整个 result
    final fallback = jsonEncode(result);
    return isError ? '错误: $fallback' : fallback;
  }
}
