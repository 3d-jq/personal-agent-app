import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/agent_colors.dart';
import '../core/app_router.dart';
import 'agent_contact_page.dart';
import 'message_list_page.dart';

/// Agent 首页（微信风格）
class AgentHomePage extends StatefulWidget {
  const AgentHomePage({super.key});

  @override
  State<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends State<AgentHomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return Scaffold(
      body: _currentIndex == 0 ? const MessageListPage() : const AgentContactPage(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: nc.surface,
          border: Border(
            top: BorderSide(color: nc.divider, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TabItem(
                  icon: PhosphorIconsRegular.chatCircle,
                  activeIcon: PhosphorIconsFill.chatCircle,
                  label: '消息',
                  isActive: _currentIndex == 0,
                  nc: nc,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _TabItem(
                  icon: PhosphorIconsRegular.robot,
                  activeIcon: PhosphorIconsFill.robot,
                  label: 'Agent',
                  isActive: _currentIndex == 1,
                  nc: nc,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab 项
class _TabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final AgentColors nc;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.nc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? nc.primary : nc.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? nc.primary : nc.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
