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

// ── AI Bubble with typing animation ──

class _AIBubble extends StatefulWidget {
  final ChatMessage msg;
  final AgentColors nc;
  const _AIBubble({required this.msg, required this.nc});

  @override
  State<_AIBubble> createState() => _AIBubbleState();
}

class _AIBubbleState extends State<_AIBubble> with SingleTickerProviderStateMixin {
  String _lastText = '';
  int _lastTextLength = 0;
  List<Widget> _cachedContent = [];
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _fadeAnim = Tween<double>(begin: 0.55, end: 1.0).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.value = 1.0;
    widget.msg.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_AIBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.msg != widget.msg || oldWidget.nc != widget.nc) {
      oldWidget.msg.removeListener(_onChanged);
      widget.msg.addListener(_onChanged);
      _lastText = '';
      _lastTextLength = 0;
      _cachedContent = [];
    }
  }

  @override
  void dispose() {
    widget.msg.removeListener(_onChanged);
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final currentLen = widget.msg.cleanText.length;
    if (currentLen > _lastTextLength && widget.msg.isStreaming) {
      _fadeCtrl.forward(from: 0.55);
    }
    _lastTextLength = currentLen;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final nc = widget.nc;
    final steps = msg.steps;
    final hasSteps = steps != null && steps.isNotEmpty;
    final textContent = msg.cleanText;

    // 找当前进行中的步骤 + 最后一个已完成的步骤
    TimelineStep? running;
    TimelineStep? lastDone;
    if (hasSteps) {
      for (final s in steps!) {
        if (s.status == TimelineStepStatus.running) {
          running = s;
          break;
        }
      }
      // 最后一个非 running 的步骤（作为完成的展示）
      for (var i = steps!.length - 1; i >= 0; i--) {
        final s = steps[i];
        if (s.status != TimelineStepStatus.running && s != running) {
          lastDone = s;
          break;
        }
      }
    }

    final showProcessLine = running != null || (msg.isStreaming && textContent.isEmpty);

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
              child: _buildProcessLine(running, lastDone, nc),
            ),
          if (textContent.isNotEmpty)
            FadeTransition(
              opacity: _fadeAnim,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _cachedContent),
            ),
        ],
      ),
    );
  }

  /// 单行步骤指示器：已完成步骤 ✓ + 进行中步骤 ⟳
  Widget _buildProcessLine(TimelineStep? running, TimelineStep? lastDone, AgentColors nc) {
    final widgets = <Widget>[];

    // 已完成步骤
    if (lastDone != null) {
      final isError = lastDone.status == TimelineStepStatus.error;
      widgets.add(
        Icon(
          isError ? Icons.close : Icons.check_circle,
          size: 16,
          color: isError ? Colors.red.shade400 : nc.success,
        ),
      );
      widgets.add(const SizedBox(width: 6));
      widgets.add(Text(
        isError ? '${lastDone.label}（失败）' : lastDone.label,
        style: TextStyle(fontSize: 13, color: nc.textSecondary, fontWeight: FontWeight.w400),
      ));
      widgets.add(const SizedBox(width: 6));
    }

    // 进行中步骤
    widgets.add(SizedBox(
      width: 16, height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        valueColor: AlwaysStoppedAnimation(nc.textSecondary),
      ),
    ));
    widgets.add(const SizedBox(width: 6));
    widgets.add(Flexible(
      child: Text(
        running?.label ?? '思考中…',
        style: TextStyle(fontSize: 13, color: nc.textSecondary, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
    ));

    return Row(children: widgets);
  }
}
