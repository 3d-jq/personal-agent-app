import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/agent_colors.dart';

/// 公共区域标题
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final AgentColors nc;

  const SectionHeader({
    super.key,
    required this.title,
    required this.nc,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: nc.textSecondary,
            ),
          ),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 6),
            Text(
              '($count)',
              style: TextStyle(fontSize: 13, color: nc.textDisabled),
            ),
          ],
        ],
      ),
    );
  }
}

/// 公共圆角卡片
class RoundedCard extends StatelessWidget {
  final AgentColors nc;
  final List<Widget> children;

  const RoundedCard({
    super.key,
    required this.nc,
    required this.children,
  });

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

/// 公共添加菜单项
class AddMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AgentColors nc;
  final VoidCallback onTap;

  const AddMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.nc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: nc.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(fontSize: 16, color: nc.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 公共添加菜单弹窗
class AddMenuSheet extends StatelessWidget {
  final AgentColors nc;
  final List<AddMenuItem> items;

  const AddMenuSheet({
    super.key,
    required this.nc,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: nc.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 0.5, color: nc.divider, indent: 16),
            items[i],
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 公通用于显示添加菜单
void showAddMenu(BuildContext context, AgentColors nc, List<AddMenuItem> items) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => AddMenuSheet(nc: nc, items: items),
  );
}
