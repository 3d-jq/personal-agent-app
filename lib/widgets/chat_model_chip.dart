import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import 'package:personal_agent_app/core/design_tokens.dart';
import 'ai_settings_sheet.dart';

class ChatModelChip extends StatelessWidget {
  final AISettings settings;
  final VoidCallback onChanged;

  const ChatModelChip({super.key, required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final vendor = settings.selectedVendor;
    if (vendor == null || vendor.model.isEmpty) return const SizedBox.shrink();
    final nc = AgentColors.of(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModelPicker(context, settings, onChanged);
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(RadiusToken.r10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(color: nc.success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(vendor.model,
                style: TextStyle(fontSize: 14, color: nc.textPrimary, fontWeight: FontWeight.w500)),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 18, color: nc.textSecondary),
          ],
        ),
      ),
    );
  }
}
