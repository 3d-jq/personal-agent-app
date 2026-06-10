import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../core/agent_colors.dart';
import 'inline_content.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final AgentColors nc;
  const ChatBubble({super.key, required this.msg, required this.nc});

  @override
  Widget build(BuildContext context) {
    if (msg.isUser) return _userBubble();
    return _aiBubble(context);
  }

  Widget _userBubble() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF37352F),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(msg.text, style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.47)),
      ),
    ),
  );

  Widget _aiBubble(BuildContext context) {
    final nc = this.nc;
    final steps = msg.steps;
    final hasSteps = steps != null && steps.isNotEmpty;
    final textContent = msg.cleanText;

    // Current running process step
    TimelineStep? running;
    if (hasSteps) {
      for (final s in steps!) {
        if (s.status == TimelineStepStatus.running) {
          running = s;
          break;
        }
      }
    }

    final showProcessLine = running != null || (msg.isStreaming && textContent.isEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Process area: single line, overwrite not append ──
          if (showProcessLine)
            Padding(
              padding: EdgeInsets.only(bottom: textContent.isNotEmpty ? 8 : 0),
              child: Row(children: [
                const SizedBox(width: 20, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(Color(0xFF9B9A97)))),
                const SizedBox(width: 10),
                Expanded(child: Text(running?.label ?? '思考中…', style: TextStyle(fontSize: 13, color: nc.textSecondary, fontWeight: FontWeight.w500))),
              ]),
            ),
          // ── Result area: clean output only ──
          if (textContent.isNotEmpty) ...buildInlineContent(textContent, nc, context),
        ],
      ),
    );
  }
}
