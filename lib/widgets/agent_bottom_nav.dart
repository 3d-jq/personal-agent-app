import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';

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
  final List<_NavData> _items = const [
    _NavData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: '主页',
    ),
    _NavData(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: '探索',
    ),
    _NavData(
      icon: Icons.layers_outlined,
      activeIcon: Icons.layers_rounded,
      label: '库',
    ),
  ];

  late AnimationController _indicatorCtrl;
  late Animation<double> _indicatorAnim;
  late double _begin;
  late double _end;

  bool _isInputMode = false;
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _begin = widget.currentIndex.toDouble();
    _end = _begin;
    _indicatorCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _indicatorAnim = Tween<double>(begin: _begin, end: _end).animate(
      CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(AgentBottomNav old) {
    super.didUpdateWidget(old);
    if (widget.currentIndex != old.currentIndex) {
      _begin = old.currentIndex.toDouble();
      _end = widget.currentIndex.toDouble();
      _indicatorAnim = Tween<double>(begin: _begin, end: _end).animate(
        CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeOutCubic),
      );
      _indicatorCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleInput() {
    HapticFeedback.lightImpact();
    setState(() => _isInputMode = !_isInputMode);
    if (_isInputMode) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _focusNode.requestFocus();
      });
    } else {
      _focusNode.unfocus();
      _inputCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final count = _items.length;

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 12 + (_isInputMode ? keyboardHeight : 0),
        ),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 400),
          crossFadeState: _isInputMode
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          sizeCurve: Curves.easeOutCubic,
          firstChild: Row(
            children: [
              Expanded(child: _buildTabNav(colors, count)),
              const SizedBox(width: 8),
              _buildEditBtn(colors),
            ],
          ),
          secondChild: Row(
            children: [
              Expanded(child: _buildInputBar(colors)),
              const SizedBox(width: 8),
              _buildCloseBtn(colors),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab nav ──

  Widget _buildTabNav(AgentColors colors, int count) {
    return SizedBox(
      height: 52,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final itemWidth = maxWidth / count;
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.divider, width: 0.5),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              AnimatedBuilder(
                animation: _indicatorAnim,
                builder: (context, _) {
                  final left = _indicatorAnim.value * itemWidth + 4;
                  return Positioned(
                    left: left,
                    top: (constraints.maxHeight - 44) / 2,
                    child: Container(
                      width: itemWidth - 8,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.primarySurface,
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
                          isSelected ? _items[i].activeIcon : _items[i].icon,
                          size: 22,
                          color: isSelected
                              ? colors.textPrimary
                              : colors.textSecondary,
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
    );
  }

  // ── Input bar ──

  Widget _buildInputBar(AgentColors colors) {
    return Container(
      key: const ValueKey('input'),
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider, width: 0.5),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          _CircleBtn(icon: Icons.add),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              focusNode: _focusNode,
              maxLines: 1,
              style: TextStyle(fontSize: 16, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: '输入...',
                hintStyle:
                    TextStyle(color: colors.textSecondary, fontSize: 16),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _CircleBtn(icon: Icons.mic),
        ],
      ),
    );
  }

  // ── Buttons ──

  Widget _buildEditBtn(AgentColors colors) {
    return GestureDetector(
      onTap: _toggleInput,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.divider, width: 0.5),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Center(
          child:
              Icon(Icons.edit_outlined, size: 22, color: colors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildCloseBtn(AgentColors colors) {
    return GestureDetector(
      onTap: _toggleInput,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.divider, width: 0.5),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Center(
          child: Icon(Icons.close, size: 22, color: colors.textPrimary),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  const _CircleBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider, width: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, size: 18, color: colors.textPrimary),
    );
  }
}

class _NavData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
