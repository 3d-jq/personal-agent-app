import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/app_config.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

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
        title: Text(
          '关于',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Text(
              'DWeis',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: nc.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '全能 AI 助手',
              style: TextStyle(fontSize: 14, color: nc.textSecondary),
            ),
          ),
          const SizedBox(height: 40),
          _SectionHeader(title: '应用信息', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
              _InfoRow(label: '版本', value: AppConfig.version, nc: nc),
              _InfoRow(label: '构建', value: '2024.01', nc: nc),
              _InfoRow(label: '框架', value: 'Flutter', nc: nc),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: '能力', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
              _CapabilityItem(
                icon: Icons.chat_bubble_outline,
                label: 'AI 对话',
                nc: nc,
              ),
              _CapabilityItem(
                icon: Icons.image_outlined,
                label: '图片生成',
                nc: nc,
              ),
              _CapabilityItem(
                icon: Icons.videocam_outlined,
                label: '视频生成',
                nc: nc,
              ),
              _CapabilityItem(icon: Icons.language, label: '网页搜索', nc: nc),
              _CapabilityItem(
                icon: Icons.bookmark_border,
                label: '记忆系统',
                nc: nc,
              ),
              _CapabilityItem(icon: Icons.note_outlined, label: '笔记管理', nc: nc),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: '开源许可', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
              _SettingItem(
                icon: Icons.description_outlined,
                label: '查看开源许可',
                onTap: () {
                  HapticFeedback.lightImpact();
                  showLicensePage(
                    context: context,
                    applicationName: 'DWeis',
                    applicationVersion: AppConfig.version,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 40),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final AgentColors nc;
  const _InfoRow({required this.label, required this.value, required this.nc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: nc.textSecondary)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, color: nc.textPrimary)),
        ],
      ),
    );
  }
}

class _CapabilityItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AgentColors nc;
  const _CapabilityItem({
    required this.icon,
    required this.label,
    required this.nc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: nc.textPrimary),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 15, color: nc.textPrimary)),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SettingItem({required this.icon, required this.label, this.onTap});

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
                  style: TextStyle(
                    fontSize: 15,
                    color: nc.textPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: nc.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
