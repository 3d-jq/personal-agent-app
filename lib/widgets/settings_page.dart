import 'package:flutter/material.dart';
import '../core/agent_colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: nc.textPrimary)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // ── User card ──
          _UserCard(nc: nc),
          const SizedBox(height: 20),

          // ── App settings ──
          _SectionHeader(title: '应用程序', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
              _SettingItem(icon: Icons.language_rounded, label: '语言', trailing: 'Chinese', onTap: () {}),
              _SettingItem(icon: Icons.brightness_6_outlined, label: '主题', trailing: '系统', onTap: () {}),
              _SettingItem(icon: Icons.volume_up_outlined, label: '语音', trailing: '少女阿月', onTap: () {}),
              _SettingItem(icon: Icons.layers_outlined, label: '模型', onTap: () {}),
              _SettingItem(icon: Icons.tune_outlined, label: '个性化', onTap: () {}),
            ],
          ),
          const SizedBox(height: 20),

          // ── About ──
          _SectionHeader(title: '关于', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
              _SettingItem(icon: Icons.description_outlined, label: '用户条款', onTap: () {}),
              _SettingItem(icon: Icons.lock_outline, label: '隐私协议', onTap: () {}),
              _SettingItem(icon: Icons.info_outline, label: '关于', onTap: () {}),
            ],
          ),
          const SizedBox(height: 12),

          // ── Contact ──
          _RoundedCard(
            nc: nc,
            children: [
              _SettingItem(icon: Icons.chat_bubble_outline, label: '联系我们', onTap: () {}),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── User card ──

class _UserCard extends StatelessWidget {
  final AgentColors nc;
  const _UserCard({required this.nc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Ren da',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: nc.textPrimary),
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: nc.textSecondary),
        ],
      ),
    );
  }
}

// ── Section header ──

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
        style: TextStyle(fontSize: 13, color: nc.textSecondary, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── Rounded card ──

class _RoundedCard extends StatelessWidget {
  final AgentColors nc;
  final List<Widget> children;
  const _RoundedCard({required this.nc, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 1))],
      ),
      child: Column(children: children),
    );
  }
}

// ── Setting item ──

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
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, color: nc.textPrimary, fontWeight: FontWeight.w400),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(fontSize: 14, color: nc.textSecondary),
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
