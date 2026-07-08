import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/chat_controller.dart';
import '../core/agent_colors.dart';

class ChatNewChatButton extends StatelessWidget {
  final ChatController controller;
  final VoidCallback onBeforeNew;

  const ChatNewChatButton({super.key, required this.controller, required this.onBeforeNew});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        onBeforeNew();
        await controller.saveSession();
        controller.newSession();
        await controller.refreshSessions();
      },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.edit_note, size: 18, color: AgentColors.of(context).textPrimary),
        ),
    );
  }
}
