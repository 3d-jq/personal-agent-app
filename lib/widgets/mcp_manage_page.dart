import 'package:flutter/material.dart';
import 'mcp_add_server_sheet.dart';
import 'mcp_edit_server_sheet.dart';
import '../core/agent_colors.dart';
import 'package:personal_agent_app/core/design_tokens.dart';
import '../core/service_locator.dart';
import '../models/mcp_server.dart';
import '../services/mcp_manager.dart';
import '../services/log_service.dart';

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
      queryParams: <String, String>{},
    ),
    (
      name: '瑞幸咖啡',
      url: 'https://gwmcp.lkcoffee.com',
      endpoint: '/order/user/mcp',
      hint: '在瑞幸 AI 开放平台申请 MCP Token',
      queryParams: <String, String>{},
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
                    borderRadius: BorderRadius.circular(RadiusToken.r10),
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
                trailing: Icon(Icons.chevron_right, size: 18, color: nc.textSecondary),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddServer(
                    presetName: t.name,
                    presetUrl: t.url,
                    presetEndpoint: t.endpoint,
                    tokenHint: t.hint,
                    presetQueryParams: t.queryParams,
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
                  borderRadius: BorderRadius.circular(RadiusToken.r10),
                ),
                child: Icon(Icons.edit, size: 18, color: nc.textSecondary),
              ),
              title: Text('手动添加', style: TextStyle(fontSize: 15, color: nc.textPrimary)),
              subtitle: Text(
                '自定义服务器信息',
                style: TextStyle(fontSize: 12, color: nc.textSecondary),
              ),
              trailing: Icon(Icons.chevron_right, size: 18, color: nc.textSecondary),
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
    Map<String, String>? presetQueryParams,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AgentColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => McpAddServerSheet(
        presetName: presetName,
        presetUrl: presetUrl,
        presetEndpoint: presetEndpoint,
        tokenHint: tokenHint,
        presetQueryParams: presetQueryParams,
        onAdd: (server) {
          setState(() => _servers.add(server));
          _saveAndSync();
        },
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AgentColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => McpEditServerSheet(
        server: server,
        onSave: (updated) {
          setState(() {
            final index = _servers.indexWhere((s) => s.id == server.id);
            if (index >= 0) _servers[index] = updated;
          });
          _saveAndSync();
        },
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
                          Icons.public,
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
                      elevation: 6,
                      child: Icon(Icons.add, color: Colors.white),
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
                      elevation: 6,
                      child: Icon(Icons.add, color: Colors.white),
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
        borderRadius: BorderRadius.circular(RadiusToken.r14),
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
                    borderRadius: BorderRadius.circular(RadiusToken.xs),
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
                    activeThumbColor: nc.success,
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
                  icon: Icons.integration_instructions,
                  label: '测试',
                  color: nc.textSecondary,
                  nc: nc,
                  onTap: onTest,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.edit,
                  label: '编辑',
                  color: nc.textSecondary,
                  nc: nc,
                  onTap: onEdit,
                ),
                const Spacer(),
                _ActionChip(
                  icon: Icons.delete,
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
          borderRadius: BorderRadius.circular(RadiusToken.sm),
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
