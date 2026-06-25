import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../core/agent_colors.dart';
import '../core/app_animations.dart';
import '../core/app_router.dart';
import '../core/service_locator.dart';
import '../services/theme_service.dart';
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
    final (lightColor, darkColor) = getIt<ThemeService>().bubbleColor;
    final bgColor = isDark ? darkColor : lightColor;
    final hasImage =
        msg.attachmentType == 'image' && msg.attachmentPath != null;
    final hasDoc =
        msg.attachmentType == 'document' && msg.attachmentPath != null;

    // Strip [附件: xxx] from display text
    final cleanText = msg.text
        .replaceAll(RegExp(r'\n?\[附件: [^\]]+\]'), '')
        .trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image preview
            if (hasImage)
              _buildImagePreview(context, msg.attachmentPath!, bgColor, nc),
            // Document card
            if (hasDoc) _buildDocumentCard(msg.attachmentPath!, bgColor, nc),
            // Text message (if any)
            if (cleanText.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  cleanText,
                  style: TextStyle(
                    fontSize: 15,
                    color: nc.textPrimary,
                    height: 1.47,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(
    BuildContext context,
    String path,
    Color bgColor,
    AgentColors nc,
  ) {
    final file = File(path);
    final heroTag = 'user_image_${path.hashCode}';
    return PressableScale(
      onTap: () {
        HapticFeedback.lightImpact();
        AppRouter.push(
          context,
          _UserImagePreview(path: path, heroTag: heroTag),
        );
      },
      child: Hero(
        tag: heroTag,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: 240,
            errorBuilder: (_, _, _) => Container(
              width: 240,
              height: 120,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 32,
                      color: nc.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '图片加载失败',
                      style: TextStyle(fontSize: 12, color: nc.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(String path, Color bgColor, AgentColors nc) {
    final file = File(path);
    final name = file.path.split(Platform.pathSeparator).last;
    final shortName = name.length > 24 ? '${name.substring(0, 21)}...' : name;
    final exists = file.existsSync();

    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.insert_drive_file_outlined,
              size: 22,
              color: nc.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: nc.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  exists ? '文档附件' : '文件不存在',
                  style: TextStyle(fontSize: 11, color: nc.textSecondary),
                ),
              ],
            ),
          ),
        ],
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

class _AIBubbleState extends State<_AIBubble>
    with SingleTickerProviderStateMixin {
  String _lastText = '';
  int _lastTextLength = 0;
  List<Widget> _cachedContent = [];
  DateTime _lastRenderTime = DateTime(2000); // far in the past
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _renderThrottle = Duration(milliseconds: 80);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = Tween<double>(
      begin: 0.55,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
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
      _lastRenderTime = DateTime(2000);
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
    final isStreaming = msg.isStreaming;

    final showProcessLine =
        hasSteps || (isStreaming && textContent.isEmpty);

    // Throttle expensive Markdown parsing during streaming
    final now = DateTime.now();
    final shouldRender = textContent != _lastText &&
        (!isStreaming || now.difference(_lastRenderTime) >= _renderThrottle);
    if (shouldRender) {
      _lastText = textContent;
      _lastRenderTime = now;
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
              child: _buildProcessLine(steps ?? const [], nc, msg.isStreaming),
            ),
          if (textContent.isNotEmpty)
            FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _cachedContent,
              ),
            ),
        ],
      ),
    );
  }

  /// 单行状态指示器：只显示当前最新的一个步骤
  Widget _buildProcessLine(
    List<TimelineStep> steps,
    AgentColors nc,
    bool isStreaming,
  ) {
    final shimmerHighlight = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.65);

    if (steps.isEmpty) {
      return ShimmerText(
        text: '思考中',
        style: TextStyle(
          fontSize: 13,
          color: nc.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        baseColor: nc.textSecondary,
        highlightColor: shimmerHighlight,
      );
    }

    final step = steps.last;
    final isRunning = step.status == TimelineStepStatus.running;
    final isError = step.status == TimelineStepStatus.error;
    final isAllDone =
        !isRunning &&
        !isError &&
        steps.every((s) => s.status == TimelineStepStatus.done);

    // 流尚未结束且最后一步是工具 → 保持扫光效果，表示流程仍在进行
    if (isAllDone && isStreaming && step.type == TimelineStepType.tool) {
      return ShimmerText(
        text: step.label,
        style: TextStyle(
          fontSize: 13,
          color: nc.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        baseColor: nc.textSecondary,
        highlightColor: shimmerHighlight,
      );
    }

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
                style: TextStyle(
                  fontSize: 13,
                  color: nc.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: nc.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      );
    }

    if (isRunning) {
      return ShimmerText(
        text: step.label,
        style: TextStyle(
          fontSize: 13,
          color: nc.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        baseColor: nc.textSecondary,
        highlightColor: shimmerHighlight,
      );
    }

if (isError) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.close,
            size: 16,
            color: Colors.red.shade400,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${step.label}（失败）',
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

    // 最后一步是 done 但前面有步骤不是（如 error），按已完成样式渲染
    if (!isRunning && !isError) {
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
                style: TextStyle(
                  fontSize: 13,
                  color: nc.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: nc.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showTimelineDetail(List<TimelineStep> steps, AgentColors nc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: nc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: nc.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '思考与工具调用',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: nc.textPrimary,
                ),
              ),
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

// ── User image full-screen preview ──

class _UserImagePreview extends StatelessWidget {
  final String path;
  final String heroTag;
  const _UserImagePreview({required this.path, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Hero(
            tag: heroTag,
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
