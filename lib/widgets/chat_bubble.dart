import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../core/agent_colors.dart';
import 'inline_content.dart';
import 'timeline_view.dart';
import 'shimmer_text.dart';

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

    final showProcessLine = hasSteps || (msg.isStreaming && textContent.isEmpty);

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
              child: _buildProcessLine(steps ?? const [], nc),
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

  /// 单行状态指示器：只显示当前最新的一个步骤
  Widget _buildProcessLine(List<TimelineStep> steps, AgentColors nc) {
    final shimmerHighlight = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.65);

    if (steps.isEmpty) {
      return ShimmerText(
        text: '思考中…',
        style: TextStyle(fontSize: 13, color: nc.textSecondary, fontWeight: FontWeight.w500),
        baseColor: nc.textSecondary,
        highlightColor: shimmerHighlight,
      );
    }

    final step = steps.last;
    final isRunning = step.status == TimelineStepStatus.running;
    final isError = step.status == TimelineStepStatus.error;
    final isAllDone = !isRunning && !isError && steps.every((s) => s.status == TimelineStepStatus.done);

    if (isAllDone) {
      return InkWell(
        onTap: () => _showTimelineDetail(steps, nc),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                step.label,
                style: TextStyle(fontSize: 13, color: nc.textSecondary, fontWeight: FontWeight.w400),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 16, color: nc.textSecondary.withValues(alpha: 0.5)),
            ],
          ),
        ),
      );
    }

    if (isRunning) {
      return ShimmerText(
        text: step.label,
        style: TextStyle(fontSize: 13, color: nc.textSecondary, fontWeight: FontWeight.w500),
        baseColor: nc.textSecondary,
        highlightColor: shimmerHighlight,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isError ? Icons.close : Icons.check_circle,
          size: 16,
          color: isError ? Colors.red.shade400 : nc.success,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            isError ? '${step.label}（失败）' : step.label,
            style: TextStyle(
              fontSize: 13,
              color: nc.textSecondary,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showTimelineDetail(List<TimelineStep> steps, AgentColors nc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: nc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: nc.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('思考与工具调用', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: nc.textPrimary)),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: TimelineView(steps: steps, nc: nc),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
