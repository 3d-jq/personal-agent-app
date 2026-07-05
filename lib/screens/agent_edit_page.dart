import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/agent_colors.dart';
import '../core/service_locator.dart';
import '../models/agent.dart';
import '../services/agent_storage.dart';
import '../widgets/ai_settings_sheet.dart';

/// Agent 编辑页面
class AgentEditPage extends StatefulWidget {
  final Agent? existing;
  const AgentEditPage({super.key, this.existing});
  @override
  State<AgentEditPage> createState() => _AgentEditPageState();
}

class _AgentEditPageState extends State<AgentEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _prompt;
  late String _vendorId;
  late String _model;
  late Set<String> _tools;
  List<VendorConfig> _vendors = const [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _role = TextEditingController(text: e?.role ?? '');
    _prompt = TextEditingController(text: e?.systemPrompt ?? '');
    _vendorId = e?.vendorId ?? '';
    _model = e?.model ?? '';
    _tools = (e?.allowedToolNames ?? const []).toSet();
    _vendors = getIt<AISettings>().vendors;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写 Agent 名字')));
      return;
    }
    final a = Agent(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      role: _role.text.trim(),
      avatar: _name.text.trim().isNotEmpty ? _name.text.trim().characters.first : '',
      systemPrompt: _prompt.text,
      vendorId: _vendorId,
      model: _model.trim(),
      allowedToolNames: _tools.toList(),
    );
    Navigator.of(context).pop(a);
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
          widget.existing == null ? '新建 Agent' : '编辑 Agent',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('保存', style: TextStyle(color: nc.success)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 头像预览
          Center(
            child: Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: nc.primarySurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: nc.divider, width: 0.5),
              ),
              child: Text(
                _name.text.isNotEmpty ? _name.text.characters.first : '?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: nc.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 名字
          _EditField(
            label: '名字',
            ctrl: _name,
            nc: nc,
            hint: '例如：产品经理',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          // 职能描述
          _EditField(
            label: '职能描述',
            ctrl: _role,
            nc: nc,
            hint: '一句话说明擅长什么',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          // System Prompt
          Text(
            'System Prompt',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '定义 Agent 的角色、风格和行为规则',
            style: TextStyle(fontSize: 12, color: nc.textSecondary),
          ),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
            child: TextField(
              controller: _prompt,
              minLines: 6,
              maxLines: 15,
              style: TextStyle(fontSize: 14, color: nc.textPrimary, height: 1.6),
              decoration: InputDecoration(
                hintText: '<role>\n你是...\n</role>',
                hintStyle: TextStyle(
                  color: nc.textDisabled,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
                filled: true,
                fillColor: nc.primarySurface,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 编辑页输入字段
class _EditField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController ctrl;
  final AgentColors nc;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _EditField({
    required this.label,
    required this.ctrl,
    required this.nc,
    this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: nc.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
          child: TextField(
            controller: ctrl,
            onChanged: onChanged,
            maxLines: maxLines,
            style: TextStyle(fontSize: 15, color: nc.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: nc.textDisabled, fontSize: 15),
              filled: true,
              fillColor: nc.primarySurface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
