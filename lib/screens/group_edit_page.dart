import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/agent_colors.dart';
import '../core/service_locator.dart';
import '../models/agent.dart';
import '../models/agent_group.dart';
import '../services/agent_storage.dart';

/// 群聊编辑页面
class GroupEditPage extends StatefulWidget {
  final AgentGroup? existing;
  const GroupEditPage({super.key, this.existing});
  @override
  State<GroupEditPage> createState() => _GroupEditPageState();
}

class _GroupEditPageState extends State<GroupEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  List<Agent> _agents = [];
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _desc = TextEditingController(text: widget.existing?.description ?? '');
    _selected = (widget.existing?.agentIds ?? const []).toSet();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    final all = await getIt<AgentStorage>().loadAll();
    if (!mounted) return;
    final dweis = all.where((a) => a.name == 'DWeis').firstOrNull;
    if (dweis != null) _selected.add(dweis.id);
    setState(() => _agents = all);
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写群名')));
      return;
    }
    final g = AgentGroup(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      description: _desc.text.trim(),
      agentIds: _selected.toList(),
      messages: widget.existing?.messages ?? const [],
    );
    Navigator.of(context).pop(g);
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: nc.background.withValues(alpha: 0.85),
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.arrowLeft, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existing == null ? '新建群' : '编辑群',
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 群名
          _EditField(label: '群名', ctrl: _name, nc: nc),
          const SizedBox(height: 16),
          // 描述
          _EditField(label: '描述（可选）', ctrl: _desc, nc: nc),
          const SizedBox(height: 24),
          // 选择 Agent
          Text(
            '选择 Agent',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (_agents.isEmpty)
            Text(
              'Agent 库是空的，先去新建一个',
              style: TextStyle(color: nc.textSecondary),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: nc.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: nc.divider, width: 0.5),
              ),
              child: Column(
                children: List.generate(_agents.length, (i) {
                  final a = _agents[i];
                  final isDweis = a.name == 'DWeis';
                  final isSelected = isDweis || _selected.contains(a.id);
                  return Column(
                    children: [
                      if (i > 0)
                        Divider(height: 1, thickness: 0.5, color: nc.divider, indent: 52),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: nc.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: nc.divider, width: 0.5),
                          ),
                          child: Text(
                            a.avatar.isNotEmpty ? a.avatar : a.name.characters.first,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: nc.textPrimary,
                            ),
                          ),
                        ),
                        title: Text(a.name),
                        subtitle: a.role.isNotEmpty ? Text(a.role, style: TextStyle(fontSize: 12, color: nc.textSecondary)) : null,
                        trailing: Icon(
                          isSelected ? PhosphorIconsRegular.checkCircle : PhosphorIconsRegular.circle,
                          color: isSelected ? nc.success : nc.textDisabled,
                          size: 20,
                        ),
                        onTap: isDweis ? null : () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (isSelected) {
                              _selected.remove(a.id);
                            } else {
                              _selected.add(a.id);
                            }
                          });
                        },
                      ),
                    ],
                  );
                }),
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
  final TextEditingController ctrl;
  final AgentColors nc;

  const _EditField({
    required this.label,
    required this.ctrl,
    required this.nc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
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
            style: TextStyle(fontSize: 15, color: nc.textPrimary),
            decoration: InputDecoration(
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
