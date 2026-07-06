import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../core/agent_colors.dart';

/// MCP 配置数据模型
class McpServer {
  final String id;
  final String name;
  final String url;
  final String? apiKey;
  final bool isEnabled;

  McpServer({
    required this.id,
    required this.name,
    required this.url,
    this.apiKey,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'apiKey': apiKey,
    'isEnabled': isEnabled,
  };

  factory McpServer.fromJson(Map<String, dynamic> json) => McpServer(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    apiKey: json['apiKey'] as String?,
    isEnabled: json['isEnabled'] as bool? ?? true,
  );

  McpServer copyWith({
    String? name,
    String? url,
    String? apiKey,
    bool? isEnabled,
  }) => McpServer(
    id: id,
    name: name ?? this.name,
    url: url ?? this.url,
    apiKey: apiKey ?? this.apiKey,
    isEnabled: isEnabled ?? this.isEnabled,
  );
}

/// MCP 管理页面
class McpManagePage extends StatefulWidget {
  const McpManagePage({super.key});

  @override
  State<McpManagePage> createState() => _McpManagePageState();
}

class _McpManagePageState extends State<McpManagePage> {
  List<McpServer> _servers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() => _loading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/mcp_servers.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as List;
        _servers = data.map((j) => McpServer.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _saveServers() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/mcp_servers.json');
    await file.writeAsString(jsonEncode(_servers.map((s) => s.toJson()).toList()));
  }

  void _showAddServer() {
    final nc = AgentColors.of(context);
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final keyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: nc.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '添加 MCP 服务器',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: nc.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: '名称',
                hintText: '例如：GitHub MCP',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: '服务器 URL',
                hintText: 'https://mcp.example.com',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              decoration: InputDecoration(
                labelText: 'API Key（可选）',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                  setState(() {
                    _servers.add(McpServer(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text,
                      url: urlCtrl.text,
                      apiKey: keyCtrl.text.isNotEmpty ? keyCtrl.text : null,
                    ));
                  });
                  _saveServers();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: nc.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServer(McpServer server) {
    final nc = AgentColors.of(context);
    final nameCtrl = TextEditingController(text: server.name);
    final urlCtrl = TextEditingController(text: server.url);
    final keyCtrl = TextEditingController(text: server.apiKey ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: nc.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '编辑 MCP 服务器',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: nc.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: '名称',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: '服务器 URL',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              decoration: InputDecoration(
                labelText: 'API Key（可选）',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                  setState(() {
                    final index = _servers.indexWhere((s) => s.id == server.id);
                    if (index >= 0) {
                      _servers[index] = server.copyWith(
                        name: nameCtrl.text,
                        url: urlCtrl.text,
                        apiKey: keyCtrl.text.isNotEmpty ? keyCtrl.text : null,
                      );
                    }
                  });
                  _saveServers();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: nc.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteServer(McpServer server) {
    final nc = AgentColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: nc.surface,
        title: Text('删除服务器', style: TextStyle(color: nc.textPrimary)),
        content: Text('确定删除「${server.name}」？', style: TextStyle(color: nc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: nc.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _servers.removeWhere((s) => s.id == server.id);
              });
              _saveServers();
            },
            child: Text('删除', style: TextStyle(color: nc.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: nc.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.arrowLeft, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'MCP 管理',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.plus, color: nc.textPrimary),
            onPressed: _showAddServer,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _servers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsRegular.globe,
                        size: 48,
                        color: nc.textSecondary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无 MCP 服务器',
                        style: TextStyle(color: nc.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击右上角 + 添加服务器',
                        style: TextStyle(fontSize: 12, color: nc.textDisabled),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _servers.length,
                  itemBuilder: (context, index) {
                    final server = _servers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: nc.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: nc.divider, width: 0.5),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: server.isEnabled
                                ? nc.success.withValues(alpha: 0.1)
                                : nc.primarySurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                    child: Icon(
                      PhosphorIconsRegular.globe,
                      size: 20,
                      color: server.isEnabled ? nc.success : nc.textSecondary,
                    ),
                        ),
                        title: Text(
                          server.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: nc.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          server.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: nc.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: server.isEnabled,
                              onChanged: (value) {
                                setState(() {
                                  final index = _servers.indexWhere((s) => s.id == server.id);
                                  if (index >= 0) {
                                    _servers[index] = server.copyWith(isEnabled: value);
                                  }
                                });
                                _saveServers();
                              },
                              activeColor: nc.success,
                            ),
                            IconButton(
                              icon: Icon(PhosphorIconsRegular.pencilSimple, size: 18, color: nc.textSecondary),
                              onPressed: () => _showEditServer(server),
                            ),
                            IconButton(
                              icon: Icon(PhosphorIconsRegular.trash, size: 18, color: nc.error),
                              onPressed: () => _deleteServer(server),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
