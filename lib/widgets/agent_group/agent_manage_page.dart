import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/agent_colors.dart';
import '../../core/app_router.dart';
import '../../models/agent.dart';
import '../../services/agent_group_storage.dart';
import '../../services/agent_storage.dart';
import '../../widgets/ai_settings_sheet.dart';
import '../../services/ai_service.dart';
import 'agent_group_theme.dart';

/// Agent 库页面
class AgentManagePage extends StatefulWidget {
  const AgentManagePage({super.key});
  @override
  State<AgentManagePage> createState() => _AgentManagePageState();
}

class _AgentManagePageState extends State<AgentManagePage> {
  List<Agent> _agents = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await AgentStorage().loadAll();
    if (!mounted) return;
    setState(() => _agents = all);
  }

  Future<void> _editOrCreate({Agent? existing}) async {
    final result = await AppRouter.editAgent(context, existing: existing);
    if (result != null) {
      if (existing == null) {
        await AgentStorage().add(result);
      } else {
        await AgentStorage().update(result);
      }
      await _load();
    }
  }

  Future<void> _delete(Agent a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除 Agent'),
        content: Text('确定删除「${a.name}」？将从所有群组中移除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      // 从所有群组中移除该 agent
      final groupStorage = AgentGroupStorage();
      final groups = await groupStorage.loadAll();
      for (final g in groups) {
        if (g.agentIds.remove(a.id)) {
          g.updatedAt = DateTime.now();
          await groupStorage.save(g);
        }
      }
      await AgentStorage().remove(a.id);
      await _load();
    }
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
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Agent 库', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: nc.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: nc.textPrimary),
            onPressed: () => _editOrCreate(),
          ),
        ],
      ),
      body: _agents.isEmpty
          ? Center(
              child: Text('暂无 Agent，点击右上角 + 新建',
                  style: TextStyle(color: nc.textSecondary)),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _SectionHeader(title: '全部 Agent', nc: nc),
                _RoundedCard(
                  nc: nc,
                  children: List.generate(_agents.length, (i) {
                    final a = _agents[i];
                    return _AgentItem(
                      agent: a,
                      nc: nc,
                      isLast: i == _agents.length - 1,
                      onTap: () => _editOrCreate(existing: a),
                      onDelete: () => _delete(a),
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
      child: Text(title, style: TextStyle(fontSize: 13, color: nc.textSecondary, fontWeight: FontWeight.w500)),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 1))],
      ),
      child: Column(children: children),
    );
  }
}

class _AgentItem extends StatelessWidget {
  final Agent agent;
  final AgentColors nc;
  final bool isLast;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const _AgentItem({
    required this.agent,
    required this.nc,
    this.isLast = false,
    this.onTap,
    this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: nc.primarySurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                    agent.avatar.isNotEmpty ? agent.avatar : agent.name.characters.first,
                    style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.name,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: nc.textPrimary)),
                    if (agent.role.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(agent.role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: nc.textSecondary)),
                      ),
                    const SizedBox(height: 2),
                    Text(toolOptionsLabel(agent.allowedToolNames),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: nc.textDisabled)),
                  ],
                ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Icon(Icons.delete_outline, size: 18, color: nc.textSecondary.withValues(alpha: 0.5)),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: nc.textSecondary.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Agent 编辑/新建页
class AgentEditPage extends StatefulWidget {
  final Agent? existing;
  const AgentEditPage({super.key, this.existing});
  @override
  State<AgentEditPage> createState() => _AgentEditPageState();
}

class _AgentEditPageState extends State<AgentEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _avatar;
  late final TextEditingController _prompt;
  late String _vendorId;
  late String _model;
  late Set<String> _tools;
  List<VendorConfig> _vendors = const [];

  String get _vendorDefaultModel {
    if (_vendorId.isEmpty) return '跟随全局默认';
    final v = _vendors.where((x) => x.id == _vendorId).firstOrNull;
    return v?.model.isNotEmpty == true ? v!.model : '未配置';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _role = TextEditingController(text: e?.role ?? '');
    _avatar = TextEditingController(text: e?.avatar ?? '');
    _prompt = TextEditingController(text: e?.systemPrompt ?? '');
    _vendorId = e?.vendorId ?? '';
    _model = e?.model ?? '';
    _tools = (e?.allowedToolNames ?? const []).toSet();
    _vendors = AISettings().vendors;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写 Agent 名字')),
      );
      return;
    }
    final a = Agent(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      role: _role.text.trim(),
      avatar: _avatar.text.trim(),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.existing == null ? '新建 Agent' : '编辑 Agent',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: nc.textPrimary)),
        centerTitle: true,
        actions: [
          TextButton(onPressed: _save, child: Text('保存', style: TextStyle(color: nc.success))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Field(label: '名字（@用）', ctrl: _name, nc: nc, hint: '例如：产品经理'),
          _Field(label: '头像 emoji', ctrl: _avatar, nc: nc, hint: '可选，例如 💡'),
          _Field(label: '职能描述', ctrl: _role, nc: nc, hint: '一句话说明擅长什么'),
          const SizedBox(height: 16),
          Text('System Prompt', style: TextStyle(fontSize: 12, color: nc.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _prompt,
            minLines: 4,
            maxLines: 10,
            style: TextStyle(fontSize: 14, color: nc.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: nc.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: '描述 Agent 的角色、风格、回答方式...',
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'AI 后端', nc: nc),
          const SizedBox(height: 8),
          _RoundedCard(
            nc: nc,
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
          if (_vendorId.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionHeader(title: '模型', nc: nc),
            const SizedBox(height: 8),
            _AgentModelPicker(
              vendorId: _vendorId,
              currentModel: _model,
              vendors: _vendors,
              onChanged: (m) => setState(() => _model = m),
            ),
          ],
          const SizedBox(height: 16),
          _SectionHeader(title: '可用工具', nc: nc),
          const SizedBox(height: 8),
          _RoundedCard(
            nc: nc,
            children: List.generate(kAgentToolOptions.length, (i) {
              final o = kAgentToolOptions[i];
              final sel = _tools.contains(o.name);
              return _ToolOption(
                label: o.label,
                selected: sel,
                nc: nc,
                isFirst: i == 0,
                isLast: i == kAgentToolOptions.length - 1,
                onTap: () {
                  setState(() {
                    if (sel) {
                      _tools.remove(o.name);
                    } else {
                      _tools.add(o.name);
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

class _Field extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController ctrl;
  final AgentColors nc;
  final ValueChanged<String>? onChanged;
  const _Field({
    required this.label,
    required this.ctrl,
    required this.nc,
    this.hint,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: nc.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            onChanged: onChanged,
            style: TextStyle(fontSize: 14, color: nc.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: nc.surface,
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 后端选择行
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        color: selected ? nc.textPrimary : nc.textSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? nc.success : nc.textDisabled,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 工具选择行
class _ToolOption extends StatelessWidget {
  final String label;
  final bool selected;
  final AgentColors nc;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  const _ToolOption({
    required this.label,
    required this.selected,
    required this.nc,
    this.isFirst = false,
    this.isLast = false,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: selected ? nc.success : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: selected ? nc.success : nc.divider,
                    width: selected ? 0 : 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: selected ? nc.textPrimary : nc.textSecondary,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Agent 编辑页的模型选择器：动态从厂商 API 获取模型列表
class _AgentModelPicker extends StatefulWidget {
  final String vendorId;
  final String currentModel;
  final List<VendorConfig> vendors;
  final ValueChanged<String> onChanged;
  const _AgentModelPicker({required this.vendorId, required this.currentModel, required this.vendors, required this.onChanged});
  @override State<_AgentModelPicker> createState() => _AgentModelPickerState();
}

class _AgentModelPickerState extends State<_AgentModelPicker> {
  List<String>? _fetched;
  bool _loading = false;
  String? _error;
  late final TextEditingController _modelCtrl;
  VendorConfig? get _vendor => widget.vendors.where((v) => v.id == widget.vendorId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _modelCtrl = TextEditingController(text: widget.currentModel);
    _fetch();
  }

  @override
  void didUpdateWidget(_AgentModelPicker old) {
    super.didUpdateWidget(old);
    if (widget.currentModel != old.currentModel && widget.currentModel != _modelCtrl.text) {
      _modelCtrl.text = widget.currentModel;
    }
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final v = _vendor; if (v == null) return;
    setState(() { _loading = true; _error = null; _fetched = null; });
    try {
      final models = await AIService(baseUrl: v.baseUrl, apiKey: v.apiKey, providerName: v.name, model: '').fetchModels();
      if (mounted) setState(() { _fetched = models; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  List<String> get _models => _fetched ?? [];
  String get _defaultModel => _vendor?.model.isNotEmpty == true ? _vendor!.model : '未配置';

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_loading) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [
        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(nc.textSecondary))),
        const SizedBox(width: 8), Text('获取模型列表...', style: TextStyle(fontSize: 12, color: nc.textSecondary)),
      ])),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        Icon(Icons.error_outline, size: 14, color: nc.error), const SizedBox(width: 6),
        Expanded(child: Text(_error!, style: TextStyle(fontSize: 11, color: nc.error))),
        TextButton(onPressed: _fetch, child: Text('重试', style: TextStyle(fontSize: 12, color: nc.success))),
      ])),
      if (_models.isNotEmpty) ...[
        Text('选择模型：', style: TextStyle(fontSize: 12, color: nc.textSecondary)),
        const SizedBox(height: 6),
        _RoundedCard(nc: nc, children: List.generate(_models.length, (i) {
          final m = _models[i]; final sel = widget.currentModel == m;
          return _VendorOption(label: m, selected: sel, nc: nc, isFirst: i == 0, isLast: i == _models.length - 1, onTap: () => widget.onChanged(m));
        })),
      ],
      const SizedBox(height: 12),
      Text('或手动输入：', style: TextStyle(fontSize: 12, color: nc.textSecondary)),
      const SizedBox(height: 6),
      TextField(
        controller: _modelCtrl,
        onChanged: (v) => widget.onChanged(v.trim()),
        style: TextStyle(fontSize: 14, color: nc.textPrimary),
        decoration: InputDecoration(
          filled: true, fillColor: nc.surface,
          hintText: '例如：gpt-4o、claude-3-opus',
          hintStyle: TextStyle(color: nc.textSecondary.withValues(alpha: 0.5), fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: widget.currentModel.isNotEmpty
              ? IconButton(icon: Icon(Icons.close, size: 18, color: nc.textSecondary), onPressed: () => widget.onChanged(''))
              : null,
        ),
      ),
    ]);
  }
}
