import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';

/// 统一底部导航（Apple 胶囊风格，2-tab：消息 / Agent）。
///
/// 圆角胶囊 + 滑动指示块 + 阴影 + 半透明毛玻璃感。
class AgentBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AgentBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AgentBottomNav> createState() => _AgentBottomNavState();
}

class _AgentBottomNavState extends State<AgentBottomNav>
    with TickerProviderStateMixin {
  final List<_NavItem> _items = const [
    _NavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: '消息',
    ),
    _NavItem(
      icon: Icons.smart_toy_outlined,
      activeIcon: Icons.smart_toy,
      label: 'Agent',
    ),
  ];

  late AnimationController _ctrl;
  late Animation<double> _anim;
  late double _begin;
  late double _end;

  @override
  void initState() {
    super.initState();
    _begin = widget.currentIndex.toDouble();
    _end = _begin;
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _anim = Tween<double>(begin: _begin, end: _end).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant AgentBottomNav old) {
    super.didUpdateWidget(old);
    if (widget.currentIndex != old.currentIndex) {
      _begin = old.currentIndex.toDouble();
      _end = widget.currentIndex.toDouble();
      _anim = Tween<double>(begin: _begin, end: _end).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final count = _items.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: SizedBox(
          height: 56,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / count;
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: nc.surface.withValues(alpha: 0.9),
                      border: Border.all(color: nc.divider, width: 0.5),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: nc.shadowMd,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      final left = _anim.value * itemWidth + 4;
                      return Positioned(
                        left: left,
                        top: (constraints.maxHeight - 44) / 2,
                        child: Container(
                          width: itemWidth - 8,
                          height: 44,
                          decoration: BoxDecoration(
                            color: nc.primarySurface,
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    children: List.generate(count, (i) {
                      final isSelected = widget.currentIndex == i;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onTap(i);
                          },
                          child: Center(
                            child: Icon(
                              isSelected
                                  ? _items[i].activeIcon
                                  : _items[i].icon,
                              size: 22,
                              color: isSelected
                                  ? nc.textPrimary
                                  : nc.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
