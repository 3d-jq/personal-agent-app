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
    if (msg.isUser) return _userBubble(context);
    return _AIBubble(msg: msg, nc: nc);
  }

  Widget _userBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A4A42) : const Color(0xFFD4EDE5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(msg.text, style: TextStyle(fontSize: 15, color: nc.textPrimary, height: 1.47)),
        ),
      ),
    );
  }
}

// ── AI Bubble: self-managing state via ChangeNotifier listener ──

class _AIBubble extends StatefulWidget {
  final ChatMessage msg;
  final AgentColors nc;
  const _AIBubble({required this.msg, required this.nc});

  @override
  State<_AIBubble> createState() => _AIBubbleState();
}

class _AIBubbleState extends State<_AIBubble> {
  String _lastText = '';
  List<Widget> _cachedContent = [];

  @override
  void initState() {
    super.initState();
    widget.msg.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_AIBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.msg != widget.msg) {
      oldWidget.msg.removeListener(_onChanged);
      widget.msg.addListener(_onChanged);
    }
    // Clear cache on any update (theme change, parent rebuild, etc.)
    _lastText = '';
  }

  @override
  void dispose() {
    widget.msg.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final nc = widget.nc;
    final steps = msg.steps;
    final hasSteps = steps != null && steps.isNotEmpty;
    final textContent = msg.cleanText;

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

    // Cache parsed markdown — only re-parse when text actually changes
    if (textContent != _lastText) {
      _lastText = textContent;
      _cachedContent = buildInlineContent(textContent, nc, context);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showProcessLine)
            Padding(
              padding: EdgeInsets.only(bottom: textContent.isNotEmpty ? 8 : 0),
              child: Row(children: [
                const SizedBox(width: 20, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(Color(0xFF9B9A97)))),
                const SizedBox(width: 10),
                Expanded(child: Text(running?.label ?? '思考中…', style: TextStyle(fontSize: 13, color: nc.textSecondary, fontWeight: FontWeight.w500))),
              ]),
            ),
          if (textContent.isNotEmpty) ..._cachedContent,
        ],
      ),
    );
  }
}
