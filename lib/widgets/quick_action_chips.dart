import 'package:flutter/material.dart';
import '../core/agent_colors.dart';

class QuickActionChips extends StatelessWidget {
  final List<String> actions;
  final ValueChanged<String>? onTap;

  const QuickActionChips({
    super.key,
    required this.actions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 12, right: 12),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: onTap != null ? () => onTap!(actions[index]) : null,
              borderRadius: BorderRadius.circular(20),
              child: _Chip(label: actions[index]),
            ),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.divider),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}
