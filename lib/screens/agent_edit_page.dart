import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/agent_colors.dart';
import '../core/service_locator.dart';
import '../models/agent.dart';
import '../services/agent_storage.dart';
import '../widgets/ai_settings_sheet.dart';
import '../widgets/agent_group/agent_group_theme.dart';

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
          const SizedBox(height: 20),
          // AI 后端
          Text(
            'AI 后端',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: nc.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: nc.divider, width: 0.5),
            ),
            child: Column(
              children: [
                _VendorOption(
                  label: '跟随全局默认',
                  selected: _vendorId.isEmpty,
                  nc: nc,
                  isFirst: true,
                  onTap: () => setState(() => _vendorId = ''),
                ),
                ...List.generate(_vendors.length, (i) {
                  final v = _vendors[i];
                  return _VendorOption(
                    label: v.name,
                    selected: _vendorId == v.id,
                    nc: nc,
                    isLast: i == _vendors.length - 1,
                    onTap: () => setState(() => _vendorId = v.id),
                  );
                }),
              ],
            ),
          ),
          if (_vendorId.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '模型',
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
                controller: TextEditingController(text: _model),
                onChanged: (v) => _model = v,
                style: TextStyle(fontSize: 15, color: nc.textPrimary),
                decoration: InputDecoration(
                  hintText: '例如：gpt-4o、claude-3-opus',
                  hintStyle: TextStyle(color: nc.textDisabled, fontSize: 15),
                  filled: true,
                  fillColor: nc.primarySurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          // 可用工具
          Text(
            '可用工具',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '选择 Agent 可以使用的工具',
            style: TextStyle(fontSize: 12, color: nc.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: nc.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: nc.divider, width: 0.5),
            ),
            child: Column(
              children: List.generate(kAgentToolOptions.length, (i) {
                final o = kAgentToolOptions[i];
                final sel = _tools.contains(o.name);
                return Column(
                  children: [
                    if (i > 0)
                      Divider(height: 1, thickness: 0.5, color: nc.divider, indent: 48),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (sel) {
                              _tools.remove(o.name);
                            } else {
                              _tools.add(o.name);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: sel ? nc.success : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: sel ? nc.success : nc.divider,
                                    width: 1,
                                  ),
                                ),
                                child: sel
                                    ? const Icon(PhosphorIconsRegular.check, size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                o.label,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: sel ? nc.textPrimary : nc.textSecondary,
                                  fontWeight: sel ? FontWeight.w500 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// AI 后端选择选项
class _VendorOption extends StatelessWidget {
  final String label;
  final bool selected;
  final AgentColors nc;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _VendorOption({
    required this.label,
    required this.selected,
    required this.nc,
    this.isFirst = false,
    this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst)
          Divider(height: 1, thickness: 0.5, color: nc.divider, indent: 48),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        color: selected ? nc.textPrimary : nc.textSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Icon(
                    selected ? PhosphorIconsRegular.checkCircle : PhosphorIconsRegular.circle,
                    color: selected ? nc.success : nc.textDisabled,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
