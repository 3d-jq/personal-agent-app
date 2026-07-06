import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../widgets/mcp_manage_page.dart';
import 'mcp_client.dart';

/// MCP 服务管理器
class McpManager {
  final Map<String, McpClient> _clients = {};

  /// 获取所有已连接的客户端
  Map<String, McpClient> get clients => Map.unmodifiable(_clients);

  /// 连接到 MCP 服务器
  Future<McpClient> connect(McpServer server) async {
    if (_clients.containsKey(server.id)) {
      return _clients[server.id]!;
    }

    final client = McpClient(
      serverUrl: server.url,
      apiKey: server.apiKey,
    );

    // 测试连接
    final connected = await client.testConnection();
    if (!connected) {
      throw Exception('无法连接到 MCP 服务器: ${server.name}');
    }

    // 获取工具列表
    await client.listTools();

    _clients[server.id] = client;
    return client;
  }

  /// 断开连接
  Future<void> disconnect(String serverId) async {
    _clients.remove(serverId);
  }

  /// 获取客户端
  McpClient? getClient(String serverId) {
    return _clients[serverId];
  }

  /// 获取所有工具定义（用于 AI 模型）
  List<Map<String, dynamic>> getAllToolDefinitions() {
    final definitions = <Map<String, dynamic>>[];
    for (final client in _clients.values) {
      definitions.addAll(client.getToolDefinitions());
    }
    return definitions;
  }

  /// 调用工具
  Future<Map<String, dynamic>> callTool(
    String serverId,
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final client = _clients[serverId];
    if (client == null) {
      throw Exception('MCP 服务器未连接: $serverId');
    }
    return await client.callTool(toolName, arguments);
  }

  /// 加载保存的服务器配置
  Future<List<McpServer>> loadServers() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/mcp_servers.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as List;
        return data.map((j) => McpServer.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 保存服务器配置
  Future<void> saveServers(List<McpServer> servers) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/mcp_servers.json');
    await file.writeAsString(jsonEncode(servers.map((s) => s.toJson()).toList()));
  }
}
