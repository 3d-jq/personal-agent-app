import 'package:flutter/material.dart';
import '../../core/agent_colors.dart';
import '../../models/agent.dart';
import '../../models/chat_message.dart';
import '../chat_bubble.dart';

/// 群聊中的单条消息气泡。
///
/// - 系统消息（加入 / 离开通知）渲染为居中胶囊提示。
/// - 用户 / Agent 消息由 [ChatBubble] 渲染；Agent 消息额外带有身份工牌
///   （头像 + 名字），用于在多 Agent 讨论中做身份隔离。
class GroupMessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final Agent? speaker;
  final AgentColors nc;

  const GroupMessageBubble({
    super.key,
    required this.msg,
    required this.speaker,
    required this.nc,
  });

  @override
  Widget build(BuildContext context) {
    // 系统消息（加入 / 离开通知）
    if (msg.speakerId == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: nc.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              msg.text,
              style: TextStyle(fontSize: 12, color: nc.textSecondary),
            ),
          ),
        ),
      );
    }

    // 流式已经结束、正文为空、且没有任何步骤（如子 Agent 无文本输出）的
    // Agent 气泡直接隐藏，避免「空气泡」；有步骤的气泡（如协调者派发后只留
    // 时间线的占位气泡）仍保留显示。
    if (!msg.isUser &&
        !msg.isStreaming &&
        speaker != null &&
        msg.text.trim().isEmpty &&
        (msg.steps == null || msg.steps!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final showHeader = speaker != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: msg.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: nc.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: nc.divider, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: nc.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: nc.divider, width: 0.5),
                      ),
                      child: Text(
                        speaker!.avatar.isNotEmpty
                            ? speaker!.avatar
                            : speaker!.name.characters.first,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      speaker!.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: nc.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ChatBubble(msg: msg, nc: nc),
        ],
      ),
    );
  }
}
