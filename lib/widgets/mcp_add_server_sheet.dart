import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../models/mcp_server.dart';

/// 新增 MCP 服务器的表单弹窗（从 [McpManagePage] 中抽取）。
///
/// 纯展示 + 本地表单逻辑：校验通过后通过 [onAdd] 回调把新建的 [McpServer]
/// 交回父级，由父级负责写入列表与持久化。
class McpAddServerSheet extends StatefulWidget {
  final void Function(McpServer) onAdd;
  final String? presetName;
  final String? presetUrl;
  final String? presetEndpoint;
  final String? tokenHint;
  final Map<String, String>? presetQueryParams;

  const McpAddServerSheet({
    super.key,
    required this.onAdd,
    this.presetName,
    this.presetUrl,
    this.presetEndpoint,
    this.tokenHint,
    this.presetQueryParams,
  });

  @override
  State<McpAddServerSheet> createState() => _McpAddServerSheetState();
}

class _McpAddServerSheetState extends State<McpAddServerSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _endpointCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.presetName ?? '');
    _urlCtrl = TextEditingController(text: widget.presetUrl ?? '');
    _keyCtrl = TextEditingController();
    _endpointCtrl = TextEditingController(text: widget.presetEndpoint ?? '/');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _endpointCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text;
    final url = _urlCtrl.text;
    if (name.isEmpty || url.isEmpty) return;

    final apiKey = _keyCtrl.text.isNotEmpty ? _keyCtrl.text : null;
    final resolvedQueryParams = <String, String>{};
    if (widget.presetQueryParams != null && apiKey != null) {
      for (final entry in widget.presetQueryParams!.entries) {
        resolvedQueryParams[entry.key] =
            entry.value.replaceAll('{apiKey}', apiKey);
      }
    }

    widget.onAdd(
      McpServer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        url: url,
        apiKey: apiKey,
        endpoint: _endpointCtrl.text.trim().isNotEmpty
            ? _endpointCtrl.text.trim()
            : '/',
        queryParams: resolvedQueryParams,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: '名称',
                hintText: '例如：GitHub MCP',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                labelText: '服务器 URL',
                hintText: 'https://mcp.example.com',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endpointCtrl,
              decoration: InputDecoration(
                labelText: '请求路径（默认 /）',
                hintText: '/ 或 /mcp',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyCtrl,
              decoration: InputDecoration(
                labelText: 'API Key（可选）',
                hintText: widget.tokenHint ?? 'MCP Token',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
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
}
