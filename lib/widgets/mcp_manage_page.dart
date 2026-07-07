import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/agent_colors.dart';
import '../core/service_locator.dart';
import '../services/mcp_manager.dart';
import '../services/log_service.dart';

/// MCP 配置数据模型
class McpServer {
  final String id;
  final String name;
  final String url;
  final String? apiKey;
  final bool isEnabled;

  /// MCP 服务的请求路径，默认 '/'。有些服务商用 '/mcp'。
  final String endpoint;

  McpServer({
    required this.id,
    required this.name,
    required this.url,
    this.apiKey,
    this.isEnabled = true,
    this.endpoint = '/',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'apiKey': apiKey,
    'isEnabled': isEnabled,
    'endpoint': endpoint,
  };

  factory McpServer.fromJson(Map<String, dynamic> json) => McpServer(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    apiKey: json['apiKey'] as String?,
    isEnabled: json['isEnabled'] as bool? ?? true,
    endpoint: json['endpoint'] as String? ?? '/',
  );

  McpServer copyWith({
    String? name,
    String? url,
    String? apiKey,
    bool? isEnabled,
    String? endpoint,
  }) => McpServer(
    id: id,
    name: name ?? this.name,
    url: url ?? this.url,
    apiKey: apiKey ?? this.apiKey,
    isEnabled: isEnabled ?? this.isEnabled,
    endpoint: endpoint ?? this.endpoint,
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
      _servers = await getIt<McpManager>().loadServers();
    } catch (e) {
      log.e('McpManagePage', '加载MCP服务器列表失败: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _saveServers() async {
    await getIt<McpManager>().saveServers(_servers);
  }

  /// 保存配置并同步连接状态（连接新启用的、断开已禁用的）
  Future<void> _saveAndSync() async {
    await _saveServers();
    await getIt<McpManager>().syncServers(_servers);
  }

  /// 预置 MCP 服务器模板
  static const _presetTemplates = [
    (
      name: '麦当劳',
      url: 'https://mcp.mcd.cn',
      endpoint: '/',
      hint: '在 https://open.mcd.cn/mcp 申请 MCP Token',
    ),
    (
      name: '瑞幸咖啡',
      url: 'https://gwmcp.lkcoffee.com',
      endpoint: '/order/user/mcp',
      hint: '在瑞幸 AI 开放平台申请 MCP Token',
    ),
  ];

  /// 添加服务器入口：选择手动添加或预置模板
  void _showAddMenu() {
    final nc = AgentColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: nc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: nc.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '添加 MCP 服务器',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: nc.textPrimary,
                ),
              ),
            ),
            // 预置模板
            for (final t in _presetTemplates)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: nc.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    t.name.characters.first,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: nc.primary,
                    ),
                  ),
                ),
                title: Text(t.name, style: TextStyle(fontSize: 15, color: nc.textPrimary)),
                subtitle: Text(
                  t.url,
                  style: TextStyle(fontSize: 12, color: nc.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(PhosphorIconsRegular.caretRight, size: 18, color: nc.textSecondary),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddServer(
                    presetName: t.name,
                    presetUrl: t.url,
                    presetEndpoint: t.endpoint,
                    tokenHint: t.hint,
                  );
                },
              ),
            Divider(height: 1, thickness: 0.5, color: nc.divider, indent: 56),
            // 手动添加
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: nc.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(PhosphorIconsRegular.pencilSimple, size: 18, color: nc.textSecondary),
              ),
              title: Text('手动添加', style: TextStyle(fontSize: 15, color: nc.textPrimary)),
              subtitle: Text(
                '自定义服务器信息',
                style: TextStyle(fontSize: 12, color: nc.textSecondary),
              ),
              trailing: Icon(PhosphorIconsRegular.caretRight, size: 18, color: nc.textSecondary),
              onTap: () {
                Navigator.pop(ctx);
                _showAddServer();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddServer({
    String? presetName,
    String? presetUrl,
    String? presetEndpoint,
    String? tokenHint,
  }) {
    final nc = AgentColors.of(context);
    final nameCtrl = TextEditingController(text: presetName ?? '');
    final urlCtrl = TextEditingController(text: presetUrl ?? '');
    final keyCtrl = TextEditingController();
    final endpointCtrl = TextEditingController(text: presetEndpoint ?? '/');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: nc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              controller: endpointCtrl,
              decoration: InputDecoration(
                labelText: '请求路径（默认 /）',
                hintText: '/ 或 /mcp',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              decoration: InputDecoration(
                labelText: 'API Key（可选）',
                hintText: tokenHint ?? 'MCP Token',
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
                      endpoint: endpointCtrl.text.trim().isNotEmpty
                          ? endpointCtrl.text.trim()
                          : '/',
                    ));
                  });
                  _saveAndSync();
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
      ),
    );
  }

  void _testConnection(McpServer server) async {
    final nc = AgentColors.of(context);
    
    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: nc.surface,
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(nc.primary),
              ),
            ),
            const SizedBox(width: 16),
            Text('正在测试连接...', style: TextStyle(color: nc.textPrimary)),
          ],
        ),
      ),
    );

    try {
      final mcpManager = getIt<McpManager>();
      final client = await mcpManager.connect(server);
      
      // 关闭加载对话框
      if (mounted) Navigator.pop(context);
      
      // connect() 内部已完成 initialize + listTools，直接读缓存的工具列表
      final tools = client.tools;
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: nc.surface,
            title: Text('连接成功', style: TextStyle(color: nc.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('已连接到 ${server.name}', style: TextStyle(color: nc.textSecondary)),
                const SizedBox(height: 8),
                Text('发现 ${tools.length} 个工具：', style: TextStyle(color: nc.textSecondary)),
                const SizedBox(height: 4),
                ...tools.map((t) => Text('• ${t.name}', style: TextStyle(fontSize: 12, color: nc.textPrimary))),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('确定', style: TextStyle(color: nc.primary)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 关闭加载对话框
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: nc.surface,
            title: Text('连接失败', style: TextStyle(color: nc.textPrimary)),
            content: Text('$e', style: TextStyle(color: nc.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('确定', style: TextStyle(color: nc.primary)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showEditServer(McpServer server) {
    final nc = AgentColors.of(context);
    final nameCtrl = TextEditingController(text: server.name);
    final urlCtrl = TextEditingController(text: server.url);
    final keyCtrl = TextEditingController(text: server.apiKey ?? '');
    final endpointCtrl = TextEditingController(text: server.endpoint);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: nc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              controller: endpointCtrl,
              decoration: InputDecoration(
                labelText: '请求路径（默认 /）',
                hintText: '/ 或 /mcp',
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
                        endpoint: endpointCtrl.text.trim().isNotEmpty
                            ? endpointCtrl.text.trim()
                            : '/',
                      );
                    }
                  });
                  _saveAndSync();
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
              _saveAndSync();
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

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _servers.isEmpty
            ? Stack(
                children: [
                  Center(
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
                          '点击右下角 + 添加服务器',
                          style: TextStyle(fontSize: 12, color: nc.textDisabled),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      onPressed: _showAddMenu,
                      backgroundColor: nc.primary,
                      child: Icon(PhosphorIconsRegular.plus, color: Colors.white),
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _servers.length,
                    itemBuilder: (context, index) {
                      final server = _servers[index];
                      final isConnected = getIt<McpManager>().clients.containsKey(server.id);
                      return _McpServerCard(
                        server: server,
                        isConnected: isConnected,
                        nc: nc,
                        onToggle: (value) {
                          setState(() {
                            final i = _servers.indexWhere((s) => s.id == server.id);
                            if (i >= 0) {
                              _servers[i] = server.copyWith(isEnabled: value);
                            }
                          });
                          _saveAndSync();
                        },
                        onTest: () => _testConnection(server),
                        onEdit: () => _showEditServer(server),
                        onDelete: () => _deleteServer(server),
                      );
                    },
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      onPressed: _showAddMenu,
                      backgroundColor: nc.primary,
                      child: Icon(PhosphorIconsRegular.plus, color: Colors.white),
                    ),
                  ),
                ],
              );
  }
}

/// MCP 服务器卡片
class _McpServerCard extends StatelessWidget {
  final McpServer server;
  final bool isConnected;
  final AgentColors nc;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _McpServerCard({
    required this.server,
    required this.isConnected,
    required this.nc,
    required this.onToggle,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = server.isEnabled;
    // 状态：已连接 > 已启用未连接 > 已禁用
    final statusColor = isConnected
        ? nc.success
        : enabled
            ? nc.warning
            : nc.textDisabled;
    final statusText = isConnected ? '已连接' : enabled ? '未连接' : '已禁用';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected ? nc.success.withValues(alpha: 0.3) : nc.divider,
          width: isConnected ? 1 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // ── 主体：图标 + 名称 + 状态 + 开关 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: enabled
                        ? nc.primary.withValues(alpha: 0.08)
                        : nc.primarySurface,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    server.name.isNotEmpty ? server.name.characters.first : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: enabled ? nc.primary : nc.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 名称 + URL
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: nc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        server.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: nc.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // 状态标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 开关
                SizedBox(
                  height: 28,
                  child: Switch(
                    value: enabled,
                    onChanged: onToggle,
                    activeColor: nc.success,
                  ),
                ),
              ],
            ),
          ),
          // ── 操作按钮行 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Row(
              children: [
                _ActionChip(
                  icon: PhosphorIconsRegular.plugs,
                  label: '测试',
                  color: nc.textSecondary,
                  nc: nc,
                  onTap: onTest,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: PhosphorIconsRegular.pencilSimple,
                  label: '编辑',
                  color: nc.textSecondary,
                  nc: nc,
                  onTap: onEdit,
                ),
                const Spacer(),
                _ActionChip(
                  icon: PhosphorIconsRegular.trash,
                  label: '删除',
                  color: nc.error,
                  nc: nc,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作按钮（chip 样式）
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final AgentColors nc;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.nc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
