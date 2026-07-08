import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../models/mcp_server.dart';

/// 编辑 MCP 服务器的表单弹窗（从 [McpManagePage] 中抽取）。
///
/// 预填 [server] 的字段，校验通过后通过 [onSave] 回调把更新后的 [McpServer]
/// 交回父级，由父级负责写回列表与持久化。
class McpEditServerSheet extends StatefulWidget {
  final McpServer server;
  final void Function(McpServer) onSave;

  const McpEditServerSheet({
    super.key,
    required this.server,
    required this.onSave,
  });

  @override
  State<McpEditServerSheet> createState() => _McpEditServerSheetState();
}

class _McpEditServerSheetState extends State<McpEditServerSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _endpointCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.server.name);
    _urlCtrl = TextEditingController(text: widget.server.url);
    _keyCtrl = TextEditingController(text: widget.server.apiKey ?? '');
    _endpointCtrl = TextEditingController(text: widget.server.endpoint);
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

    widget.onSave(
      widget.server.copyWith(
        name: name,
        url: url,
        apiKey: _keyCtrl.text.isNotEmpty ? _keyCtrl.text : null,
        endpoint: _endpointCtrl.text.trim().isNotEmpty
            ? _endpointCtrl.text.trim()
            : '/',
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
              '编辑 MCP 服务器',
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
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                labelText: '服务器 URL',
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
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
