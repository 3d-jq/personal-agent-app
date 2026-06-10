import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '库',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '你的内容',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textSecondary,
                        height: 1.43,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => HapticFeedback.lightImpact(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primarySurface,
                    border: Border.all(color: colors.divider, width: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.add, size: 18, color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _TabBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  border: Border.all(color: colors.divider, width: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: colors.textSecondary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatefulWidget {
  const _TabBar();

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> {
  int _selected = 0;
  final List<String> _tabs = ['图像', '页面', '研究', '播客'];

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          final isActive = _selected == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selected = index);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? colors.primarySurface : colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.divider, width: 0.5),
                ),
                child: Text(
                  _tabs[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                    height: 1.43,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
