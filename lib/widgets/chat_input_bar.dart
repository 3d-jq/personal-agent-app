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
  final bool isAwaitingReply;
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
    this.isAwaitingReply = false,
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
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
    widget.focusNode.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final hasFile = widget.pendingFile != null;
    final hasText = widget.controller.text.isNotEmpty;
    final isFocused = widget.focusNode.hasFocus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasFile) _buildPreview(nc),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: nc.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasFile
                    ? nc.success.withValues(alpha: 0.4)
                    : isFocused
                    ? nc.primary.withValues(alpha: 0.4)
                    : nc.divider,
                width: isFocused ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLines: 6,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      fontSize: 15,
                      color: nc.textPrimary,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.isAwaitingReply
                          ? '回复以继续…'
                          : (hasFile ? '添加描述（可选）' : '给 DWeis 发消息'),
                      hintStyle: TextStyle(
                        color: nc.textSecondary.withValues(alpha: 0.6),
                        fontSize: 15,
                        height: 1.5,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    children: [
                      _buildAttachmentButton(nc, hasFile),
                      const Spacer(),
                      _buildSendButton(nc, hasText, hasFile),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.only(bottom: widget.bottomSafe + 6),
          child: Text(
            '大模型也会出错，请谨慎核对内容',
            style: TextStyle(
              fontSize: 11,
              color: nc.textSecondary.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentButton(AgentColors nc, bool hasFile) {
    if (widget.isAwaitingReply) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (widget.onAttachment != null) {
          AttachmentPicker.show(context, nc, widget.onAttachment!);
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: hasFile
              ? nc.success.withValues(alpha: 0.1)
              : nc.primarySurface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          hasFile ? Icons.check_rounded : Icons.add_rounded,
          size: 20,
          color: hasFile ? nc.success : nc.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSendButton(AgentColors nc, bool hasText, bool hasFile) {
    final isActive = hasText || hasFile || widget.isLoading;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (widget.isLoading) {
          widget.onStop();
        } else {
          widget.onSend();
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: widget.isLoading
              ? nc.error.withValues(alpha: 0.1)
              : isActive
              ? nc.primary
              : nc.primarySurface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.isLoading ? Icons.stop_rounded : Icons.arrow_upward_rounded,
          size: 18,
          color: widget.isLoading
              ? nc.error
              : isActive
              ? nc.surface
              : nc.textSecondary,
        ),
      ),
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
                child: Image.file(
                  file,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: nc.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      size: 18,
                      color: nc.textSecondary,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: nc.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  size: 18,
                  color: nc.textSecondary,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: nc.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isImage ? '图片 · 点击加号更换' : '文档 · 点击加号更换',
                    style: TextStyle(fontSize: 11, color: nc.textSecondary),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (widget.onClearAttachment != null)
                  widget.onClearAttachment!();
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: nc.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 14, color: nc.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
