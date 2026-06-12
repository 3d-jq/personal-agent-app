import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../services/personalization_storage.dart';

class PersonalizationView extends StatefulWidget {
  const PersonalizationView({super.key});
  @override
  State<PersonalizationView> createState() => _PersonalizationViewState();
}

class _PersonalizationViewState extends State<PersonalizationView> {
  final _storage = PersonalizationStorage();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _storage.load().then((_) => setState(() => _loaded = true));
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    if (!_loaded) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('个性化', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: nc.textPrimary)),
        centerTitle: true,
      ),
      body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 8),
        _SectionHeader(title: '基本信息', nc: nc),
        _RoundedCard(
          nc: nc,
          children: [
            _SettingItem(
              icon: Icons.person_outline,
              label: '用户昵称',
              trailing: _storage.userName,
              onTap: () => _editName(context, nc),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionHeader(title: 'AI 回复风格', nc: nc),
        _RoundedCard(
          nc: nc,
          children: _storage.availableStyles.map((style) {
            final isSelected = _storage.aiStyle == style;
            return _StyleItem(
              label: style,
              isSelected: isSelected,
              nc: nc,
              onTap: () {
                setState(() => _storage.aiStyle = style);
                _storage.save();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _SectionHeader(title: '自定义系统提示词', nc: nc),
        _RoundedCard(
          nc: nc,
          children: [
            _SettingItem(
              icon: Icons.edit_note,
              label: '编辑提示词',
              trailing: _storage.customPrompt.isEmpty ? '未设置' : '已设置',
              onTap: () => _editPrompt(context, nc),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
      ),
    );
  }

  void _editName(BuildContext context, AgentColors nc) {
    final ctrl = TextEditingController(text: _storage.userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入你的昵称', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                setState(() => _storage.userName = name);
                _storage.save();
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _editPrompt(BuildContext context, AgentColors nc) {
    final ctrl = TextEditingController(text: _storage.customPrompt);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义系统提示词'),
        content: SizedBox(
          height: 200,
          child: TextField(
            controller: ctrl,
            maxLines: null,
            expands: true,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '例如：你是一个专业的编程助手...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              setState(() => _storage.customPrompt = ctrl.text.trim());
              _storage.save();
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 1))],
      ),
      child: Column(children: children),
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

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  const _SettingItem({required this.icon, required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: nc.textPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 15, color: nc.textPrimary, fontWeight: FontWeight.w400)),
              ),
              if (trailing != null)
                Text(trailing!, style: TextStyle(fontSize: 14, color: nc.textSecondary)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: nc.textSecondary.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final AgentColors nc;
  final VoidCallback onTap;
  const _StyleItem({required this.label, required this.isSelected, required this.nc, required this.onTap});

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
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20,
                color: isSelected ? const Color(0xFF0F7B6C) : nc.textSecondary,
              ),
              const SizedBox(width: 14),
              Text(label, style: TextStyle(fontSize: 15, color: nc.textPrimary, fontWeight: FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}
