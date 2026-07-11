import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../core/app_animations.dart';
import '../widgets/app_toast.dart';

class AttachmentPicker extends StatelessWidget {
  final AgentColors nc;
  final Function(File file, String type) onPicked;

  const AttachmentPicker({super.key, required this.nc, required this.onPicked});

  static Future<void> show(
    BuildContext context,
    AgentColors nc,
    Function(File, String) onPicked,
  ) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: nc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AttachmentPicker(nc: nc, onPicked: onPicked),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: nc.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              '添加附件',
              style: TextStyle(
                fontSize: 13,
                color: nc.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: nc.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: nc.divider, width: 0.5),
            ),
            child: Column(
              children: [
                _PickerItem(
                  icon: Icons.image,
                  label: '图片',
                  nc: nc,
                  onTap: () => _pickFile(context, FileType.image, 'image'),
                ),
                Divider(height: 1, thickness: 0.5, color: nc.divider),
                _PickerItem(
                  icon: Icons.description,
                  label: '文档',
                  nc: nc,
                  isLast: true,
                  onTap: () => _pickFile(context, FileType.any, 'document'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile(
    BuildContext context,
    FileType type,
    String category,
  ) async {
    Navigator.pop(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        onPicked(file, category);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, '选择文件失败: $e', type: ToastType.error);
      }
    }
  }
}

class _PickerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AgentColors nc;
  final bool isLast;
  final VoidCallback onTap;

  const _PickerItem({
    required this.icon,
    required this.label,
    required this.nc,
    this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: PressableScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: nc.textPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, color: nc.textPrimary),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: nc.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
