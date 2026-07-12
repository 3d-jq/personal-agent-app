import 'package:flutter/material.dart';

import 'package:personal_agent_app/controllers/chat_controller.dart';
import 'package:personal_agent_app/widgets/agent_side_drawer.dart';
import 'package:personal_agent_app/widgets/chat_model_chip.dart';

/// 侧边栏抽屉内容：会话列表 + 新建/删除。从 [ChatScreen] 抽出独立渲染组件。
class ChatDrawerContent extends StatelessWidget {
  final ChatController controller;
  final ValueChanged<String> onSessionTap;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSessionDeleted;

  const ChatDrawerContent({
    super.key,
    required this.controller,
    required this.onSessionTap,
    required this.onNewChat,
    required this.onSessionDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => AgentSideDrawer(
        sessions: controller.sessions,
        currentSessionId: controller.currentSessionId,
        isLoading: controller.isLoading,
        onSessionTap: onSessionTap,
        onNewChat: onNewChat,
        onSessionDeleted: onSessionDeleted,
      ),
    );
  }
}

/// 顶栏的模型选择胶囊。从 [ChatScreen] 抽出独立渲染组件。
///
/// 命名为 ChatModelChipButton 以避开所引用的真实 [ChatModelChip] 组件。
class ChatModelChipButton extends StatelessWidget {
  final ChatController controller;
  const ChatModelChipButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.aiSettings,
      builder: (context, child) => ChatModelChip(
        settings: controller.aiSettings,
        onChanged: () {},
      ),
    );
  }
}
