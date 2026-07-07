import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../services/crypto_util.dart';
import '../widgets/mcp_manage_page.dart';
import 'mcp_client.dart';

/// MCP 服务管理器
class McpManager {
  final Map<String, McpClient> _clients = {};

  /// 获取所有已连接的客户端
  Map<String, McpClient> get clients => Map.unmodifiable(_clients);

  /// 连接到 MCP 服务器
  ///
  /// 执行完整的 MCP 连接流程：initialize 握手 → 获取工具列表。
  /// 失败时抛出异常。
  Future<McpClient> connect(McpServer server) async {
    if (_clients.containsKey(server.id)) {
      return _clients[server.id]!;
    }

    final client = McpClient(
      serverUrl: server.url,
      apiKey: server.apiKey,
      endpoint: server.endpoint,
    );

    // 完整连接流程：initialize + listTools
    try {
      await client.connect();
    } catch (e) {
      throw Exception('无法连接到 MCP 服务器: ${server.name} ($e)');
    }

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

  // ═══ 配置持久化（apiKey 加密存储） ═══

  /// 加载保存的服务器配置（apiKey 自动解密）
  Future<List<McpServer>> loadServers() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/mcp_servers.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as List;
        return data.map((j) {
          final map = j as Map<String, dynamic>;
          // 解密 apiKey
          final encKey = map['apiKey'] as String?;
          if (encKey != null && encKey.isNotEmpty) {
            map['apiKey'] = CryptoUtil.decrypt(encKey);
          }
          return McpServer.fromJson(map);
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 保存服务器配置（apiKey 加密存储）
  Future<void> saveServers(List<McpServer> servers) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/mcp_servers.json');
    final jsonList = servers.map((s) {
      final map = s.toJson();
      // 加密 apiKey
      final key = map['apiKey'] as String?;
      if (key != null && key.isNotEmpty) {
        map['apiKey'] = CryptoUtil.encrypt(key);
      }
      return map;
    }).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  // ═══ 自动重连 ═══

  /// 启动时加载配置并自动连接所有 isEnabled 的服务器。
  ///
  /// 单个服务器连接失败不会中断其他服务器的连接。
  /// 返回成功连接的服务器数量。
  Future<int> autoConnect() async {
    final servers = await loadServers();
    var connected = 0;
    for (final s in servers) {
      if (!s.isEnabled) continue;
      if (_clients.containsKey(s.id)) {
        connected++;
        continue;
      }
      try {
        await connect(s);
        connected++;
      } catch (_) {
        // 单个服务器连接失败，跳过，不影响其他
      }
    }
    return connected;
  }

  /// 同步服务器状态：连接新启用的、断开已禁用的、刷新已变更的。
  ///
  /// 在 UI 上修改服务器配置后调用，确保连接状态与配置一致。
  Future<void> syncServers(List<McpServer> servers) async {
    final enabledIds = servers.where((s) => s.isEnabled).map((s) => s.id).toSet();

    // 断开已禁用或已删除的服务器
    final toDisconnect = _clients.keys
        .where((id) => !enabledIds.contains(id))
        .toList();
    for (final id in toDisconnect) {
      await disconnect(id);
    }

    // 连接新启用的服务器（已连接的跳过）
    for (final s in servers) {
      if (!s.isEnabled) continue;
      if (_clients.containsKey(s.id)) continue;
      try {
        await connect(s);
      } catch (_) {}
    }
  }
}
