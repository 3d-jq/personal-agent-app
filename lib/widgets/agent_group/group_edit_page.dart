import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/agent_colors.dart';
import '../../models/agent.dart';
import '../../models/agent_group.dart';
import '../../core/service_locator.dart';
import '../../services/agent_storage.dart';

/// 新建/编辑群
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
    // DWeis Agent 默认自动加入（必须在 loadAll 之后）
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
    // 计算成员变更
    final oldIds = (widget.existing?.agentIds ?? const []).toSet();
    final newIds = _selected;
    final addedIds = newIds.difference(oldIds);
    final removedIds = oldIds.difference(newIds);
    final addedNames = _agents
        .where((a) => addedIds.contains(a.id))
        .map((a) => a.name)
        .toList();
    final removedNames = _agents
        .where((a) => removedIds.contains(a.id))
        .map((a) => a.name)
        .toList();

    final g = AgentGroup(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      description: _desc.text.trim(),
      agentIds: _selected.toList(),
      messages: widget.existing?.messages ?? const [],
    );
    Navigator.of(context).pop((g, addedNames, removedNames));
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
          _SectionHeader(title: '群信息', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
              _FieldRow(label: '群名', ctrl: _name, nc: nc),
              _FieldRow(label: '描述（可选）', ctrl: _desc, nc: nc, isLast: true),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: '选择 Agent', nc: nc),
          if (_agents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Agent 库是空的，先去 Agent 库建一个',
                style: TextStyle(color: nc.textSecondary),
              ),
            )
          else
            _RoundedCard(
              nc: nc,
              children: List.generate(_agents.length, (i) {
                final a = _agents[i];
                final isDweis = a.name == 'DWeis';
                return _AgentPickRow(
                  agent: a,
                  selected: isDweis ? true : _selected.contains(a.id),
                  locked: isDweis,
                  nc: nc,
                  isLast: i == _agents.length - 1,
                  onChanged: isDweis
                      ? null
                      : (sel) {
                          setState(() {
                            if (sel) {
                              _selected.add(a.id);
                            } else {
                              _selected.remove(a.id);
                            }
                          });
                        },
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AgentColors nc;
  const _SectionHeader({required this.title, required this.nc});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: nc.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _RoundedCard extends StatelessWidget {
  final AgentColors nc;
  final List<Widget> children;
  const _RoundedCard({required this.nc, required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nc.divider, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final AgentColors nc;
  final bool isLast;
  const _FieldRow({
    required this.label,
    required this.ctrl,
    required this.nc,
    this.isLast = false,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: nc.textSecondary),
                ),
                const SizedBox(height: 6),
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
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, thickness: 0.5, color: nc.divider, indent: 16),
      ],
    );
  }
}

class _AgentPickRow extends StatelessWidget {
  final Agent agent;
  final bool selected;
  final bool locked;
  final AgentColors nc;
  final bool isLast;
  final ValueChanged<bool>? onChanged;
  const _AgentPickRow({
    required this.agent,
    required this.selected,
    this.locked = false,
    required this.nc,
    this.isLast = false,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: locked ? null : () => onChanged?.call(!selected),
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: nc.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: nc.divider, width: 0.5),
                    ),
                    child: Text(
                      agent.avatar.isNotEmpty
                          ? agent.avatar
                          : agent.name.characters.first,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: nc.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              agent.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: nc.textPrimary,
                              ),
                            ),
                            if (locked)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: nc.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '默认',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: nc.success,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (agent.role.isNotEmpty)
                          Text(
                            agent.role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: nc.textSecondary),
                          ),
                      ],
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
        if (!isLast)
          Divider(height: 1, thickness: 0.5, color: nc.divider, indent: 66),
      ],
    );
  }
}
