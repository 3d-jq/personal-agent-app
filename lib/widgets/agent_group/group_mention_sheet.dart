import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/agent_colors.dart';
import '../../models/agent.dart';

/// 弹出 @ Agent 选择面板，选中后把 `@名字 ` 插入到输入框光标处。
///
/// 从 [GroupChatScreen] 中抽取出来的纯 UI 辅助函数，便于独立测试。
void showGroupMentionSheet(
  BuildContext context, {
  required List<Agent> members,
  required TextEditingController controller,
  required FocusNode focusNode,
}) {
  if (members.isEmpty) return;
  final nc = AgentColors.of(context);

  void insertAt(String name) {
    final cur = controller.text;
    final sel = controller.selection;
    final pos = sel.start.clamp(0, cur.length);
    final insert = '@$name ';
    controller.value = TextEditingValue(
      text: cur.replaceRange(pos, pos, insert),
      selection: TextSelection.collapsed(offset: pos + insert.length),
    );
    focusNode.requestFocus();
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: nc.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      expand: false,
      builder: (ctx, scrollCtrl) => SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: nc.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '选择要 @ 的 Agent',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: nc.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final a = members[index];
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: nc.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: nc.divider, width: 0.5),
                      ),
                      child: Text(
                        a.avatar.isNotEmpty
                            ? a.avatar
                            : a.name.characters.first,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: nc.textPrimary,
                        ),
                      ),
                    ),
                    title: Text(
                      a.name,
                      style: TextStyle(fontSize: 15, color: nc.textPrimary),
                    ),
                    subtitle: a.role.isNotEmpty
                        ? Text(
                            a.role,
                            style: TextStyle(
                              fontSize: 12,
                              color: nc.textSecondary,
                            ),
                          )
                        : null,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      insertAt(a.name);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
