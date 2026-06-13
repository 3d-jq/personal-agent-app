import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import 'ai_settings_sheet.dart';
import 'attachment_picker.dart';

class ChatInputBar extends StatefulWidget {
  final double bottomSafe;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool isLoading;
  final AISettings settings;
  final VoidCallback onChanged;
  final File? pendingFile;
  final String pendingFileType;
  final Function(File file, String type)? onAttachment;
  final VoidCallback? onClearAttachment;

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
    this.pendingFile,
    this.pendingFileType = '',
    this.onAttachment,
    this.onClearAttachment,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final hasFile = widget.pendingFile != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasFile) _buildPreview(nc),
        AnimatedPadding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, widget.bottomSafe + 16),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: nc.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: hasFile ? nc.success.withValues(alpha: 0.4) : nc.divider,
                width: hasFile ? 1 : 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 4),
                  GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (widget.onAttachment != null) {
                      AttachmentPicker.show(context, nc, widget.onAttachment!);
                    }
                  },
                  child: Container(
                    width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: hasFile ? nc.success.withValues(alpha: 0.1) : nc.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasFile ? Icons.check_rounded : Icons.add_rounded,
                    size: 20,
                    color: hasFile ? nc.success : nc.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(fontSize: 15, color: nc.textPrimary),
                    decoration: InputDecoration(
                      hintText: hasFile ? '添加描述（可选）' : '给 DWeis 发消息',
                      hintStyle: TextStyle(
                        color: nc.textSecondary.withValues(alpha: 0.6),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (widget.isLoading) {
                      widget.onStop();
                    } else {
                      widget.onSend();
                    }
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: widget.isLoading
                          ? Colors.red.withValues(alpha: 0.1)
                          : widget.controller.text.isEmpty && !hasFile
                              ? nc.primarySurface
                              : nc.textPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isLoading ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                      size: 18,
                      color: widget.isLoading
                          ? Colors.red
                          : widget.controller.text.isEmpty && !hasFile
                              ? nc.textSecondary
                              : nc.surface,
                    ),
                  ),
                ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(AgentColors nc) {
    final file = widget.pendingFile!;
    final isImage = widget.pendingFileType == 'image';
    final name = file.path.split(Platform.pathSeparator).last;
    final shortName = name.length > 20 ? '${name.substring(0, 17)}...' : name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: nc.primarySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: nc.divider, width: 0.5),
        ),
        child: Row(
          children: [
            if (isImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(file, width: 32, height: 32, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: nc.surface, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.image_outlined, size: 18, color: nc.textSecondary),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: nc.surface, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.insert_drive_file_outlined, size: 18, color: nc.textSecondary),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shortName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: nc.textPrimary, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 1),
                  Text(isImage ? '图片 · 点击加号更换' : '文档 · 点击加号更换',
                    style: TextStyle(fontSize: 11, color: nc.textSecondary)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (widget.onClearAttachment != null) widget.onClearAttachment!();
              },
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: nc.surface, shape: BoxShape.circle),
                child: Icon(Icons.close, size: 14, color: nc.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
