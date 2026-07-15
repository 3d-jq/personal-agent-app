import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../core/app_animations.dart';

/// 聊天列表「回到底部」浮钮：用户上滑离开底部时出现。
///
/// - 无未读：圆形实底小按钮（**直径固定 36**，靠 [BoxConstraints] 最小尺寸保证，
///   避免被 18px 图标贴边缩成看不见的小点）。
/// - 有未读：胶囊药丸，显示「N 条新消息」+ 下箭头，按 [AppDurations.fast] 平滑切换。
///
/// 历史回归：当初「n 条新消息」浮条 feature 用 [AnimatedContainer] 且未给尺寸/无
/// 未读时 padding 为 0，导致无未读圆被压成 ~18px；这里用固定最小 36×36 修正。
class ChatScrollToBottomButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const ChatScrollToBottomButton({
    super.key,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final hasUnread = unread > 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.appear,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.symmetric(
          horizontal: hasUnread ? 16 : 0,
          vertical: hasUnread ? 10 : 0,
        ),
        decoration: hasUnread
            ? BoxDecoration(
                color: nc.primary,
                borderRadius: BorderRadius.circular(20),
              )
            : BoxDecoration(
                color: nc.surface,
                shape: BoxShape.circle,
                border: Border.all(color: nc.divider, width: 0.5),
              ),
        child: hasUnread
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$unread 条新消息',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              )
            : Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: nc.textPrimary,
              ),
      ),
    );
  }
}
