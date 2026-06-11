import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import 'ai_settings_sheet.dart';

class ChatInputBar extends StatefulWidget {
  final double bottomSafe;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool isLoading;
  final AISettings settings;
  final VoidCallback onChanged;

  const ChatInputBar({
    super.key,
    required this.bottomSafe,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onStop,
    required this.isLoading,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return AnimatedPadding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, widget.bottomSafe + 16),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: nc.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSend(),
                  style: TextStyle(fontSize: 15, color: nc.textPrimary),
                  decoration: InputDecoration(
                    hintText: '询问、搜索或创作任何内容',
                    hintStyle: TextStyle(
                      color: nc.textSecondary.withValues(alpha: 0.7),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.add_rounded, size: 22, color: nc.textSecondary),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showBackendPicker(context, widget.settings, widget.onChanged);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.memory_rounded,
                      size: 22,
                      color: widget.settings.hasVendor
                          ? const Color(0xFF0F7B6C)
                          : const Color(0xFFDFAB01),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.isLoading ? widget.onStop : widget.onSend,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: nc.textPrimary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: widget.isLoading
                        ? Icon(Icons.stop_rounded, size: 18, color: nc.surface)
                        : Icon(Icons.arrow_upward_rounded, size: 18, color: nc.surface),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
