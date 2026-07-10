import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../core/agent_colors.dart';
import '../core/design_tokens.dart';
import '../core/app_animations.dart';
import '../core/app_router.dart';
import '../widgets/app_toast.dart';
import 'inline_content.dart';
import 'timeline_view.dart';
import 'shimmer_text.dart';
import 'task_plan_panel.dart';

enum _BubbleAction { copy, regenerate, delete }

class ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final AgentColors nc;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final VoidCallback? onRegenerate;
  const ChatBubble({
    super.key,
    required this.msg,
    required this.nc,
    this.onRetry,
    this.onDelete,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final child = msg.isUser
        ? _userBubble(context)
        : _AIBubble(msg: msg, nc: nc, onRetry: onRetry);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (d) => _showActionMenu(context, d.globalPosition),
      child: child,
    );
  }

  void _copy(BuildContext context) {
    final text = msg.cleanText.isNotEmpty ? msg.cleanText : msg.text;
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    AppToast.show(context, '已复制');
  }

  void _showActionMenu(BuildContext context, Offset globalPos) async {
    final nc = AgentColors.of(context);
    final menuItems = <PopupMenuEntry<_BubbleAction>>[
      PopupMenuItem<_BubbleAction>(
        value: _BubbleAction.copy,
        child: _menuRow(nc, Icons.content_copy, '复制', false),
      ),
    ];
    if (onRegenerate != null) {
      menuItems.add(
        PopupMenuItem<_BubbleAction>(
          value: _BubbleAction.regenerate,
          child: _menuRow(nc, Icons.refresh, '重新生成', false),
        ),
      );
    }
    if (onDelete != null) {
      menuItems.add(
        PopupMenuItem<_BubbleAction>(
          value: _BubbleAction.delete,
          child: _menuRow(nc, Icons.delete_outline, '删除', true),
        ),
      );
    }

    final result = await showMenu<_BubbleAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx,
        globalPos.dy,
      ),
      color: nc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusToken.md),
      ),
      elevation: 8,
      items: menuItems,
    );

    switch (result) {
      case _BubbleAction.copy:
        _copy(context);
      case _BubbleAction.regenerate:
        onRegenerate?.call();
      case _BubbleAction.delete:
        onDelete?.call();
      case null:
        break;
    }
  }

  Widget _menuRow(
    AgentColors nc,
    IconData icon,
    String label,
    bool destructive,
  ) {
    final color = destructive ? nc.error : nc.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: SpaceToken.md),
        Text(label, style: TextStyle(fontSize: FontToken.body, color: color)),
      ],
    );
  }

  Widget _userBubble(BuildContext context) {
    // Apple HIG：用户消息用 system-blue 填充 + 白色文字
    final bgColor = nc.primary;
    final hasImage =
        msg.attachmentType == 'image' && msg.attachmentPath != null;
    final hasDoc =
        msg.attachmentType == 'document' && msg.attachmentPath != null;

    // Strip [附件: xxx] from display text
    final cleanText = msg.text
        .replaceAll(RegExp(r'\n?\[附件: [^\]]+\]'), '')
        .trim();

    final bubble = Padding(
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
            // 附件和文字之间的间距
            if ((hasImage || hasDoc) && cleanText.isNotEmpty)
              const SizedBox(height: 6),
            // Text message (if any)
            if (cleanText.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  // Apple HIG：连续曲率圆角，无边框
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cleanText,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return TweenAnimationBuilder<double>(
      duration: AppDurations.bubble,
      curve: Curves.easeOut,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 8),
          child: child,
        ),
      ),
      child: bubble,
    );
  }

  Widget _buildImagePreview(
    BuildContext context,
    String path,
    Color bgColor,
    AgentColors nc,
  ) {
    final file = File(path);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final heroTag = 'user_image_${Object.hash(runtimeType, path)}';
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
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: 240,
            cacheWidth: (240 * dpr).round(),
            errorBuilder: (_, _, _) => Container(
              width: 240,
              height: 120,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image,
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

    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
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
              Icons.description,
              size: 22,
              color: Colors.white.withValues(alpha: 0.9),
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
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '文档附件',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
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
  final VoidCallback? onRetry;
  const _AIBubble({required this.msg, required this.nc, this.onRetry});

  @override
  State<_AIBubble> createState() => _AIBubbleState();
}

class _AIBubbleState extends State<_AIBubble>
    with TickerProviderStateMixin {
  String _lastText = '';
  bool _planExpanded = true;
  List<Widget> _cachedContent = [];
  // 增量富文本缓存：已完成块的渲染结果与对应原文，避免每帧全量重解析
  final List<List<Widget>> _frozenBlockWidgets = [];
  final List<String> _frozenBlockTexts = [];
  late AnimationController _enterCtrl;
  late Animation<double> _enterOpacity;
  late Animation<Offset> _enterOffset;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: AppDurations.bubble,
    );
    _enterOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut),
    );
    _enterOffset = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterCtrl.forward();
  }

  @override
  void didUpdateWidget(_AIBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.msg != widget.msg || oldWidget.nc != widget.nc) {
      _lastText = '';
      _cachedContent = [];
      _planExpanded = true;
      _frozenBlockWidgets.clear();
      _frozenBlockTexts.clear();
    }
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  /// 将流式文本按 markdown 块边界切分：空行分隔段落，``` 围栏跨空行保留为整块。
  /// 仅用于增量渲染的缓存粒度，不影响最终渲染正确性（flutter_markdown 自身按块解析）。
  static List<String> _splitBlocks(String text) {
    final lines = text.split('\n');
    final blocks = <String>[];
    final buf = <String>[];
    var inFence = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('```')) {
        if (!inFence) {
          if (buf.isNotEmpty) {
            blocks.add(buf.join('\n'));
            buf.clear();
          }
          inFence = true;
          buf.add(line);
        } else {
          buf.add(line);
          blocks.add(buf.join('\n'));
          buf.clear();
          inFence = false;
        }
      } else if (!inFence && trimmed.isEmpty) {
        if (buf.isNotEmpty) {
          blocks.add(buf.join('\n'));
          buf.clear();
        }
      } else {
        buf.add(line);
      }
    }
    if (buf.isNotEmpty) blocks.add(buf.join('\n'));
    return blocks;
  }

  /// 增量重建流式富文本：已完成块（除最后一块）命中缓存则直接复用，
  /// 仅对最后一个正在生长的块重新解析并渲染。
  List<Widget> _rebuildStreaming(String text) {
    final blocks = _splitBlocks(text);
    final result = <Widget>[];
    final completedCount = blocks.length - 1;
    // 流式文本只增不减，completedCount 应单调增长；异常兜底截断缓存
    if (_frozenBlockWidgets.length > completedCount) {
      _frozenBlockWidgets.length = completedCount;
      _frozenBlockTexts.length = completedCount;
    }
    for (var i = 0; i < completedCount; i++) {
      if (i < _frozenBlockTexts.length &&
          i < _frozenBlockWidgets.length &&
          _frozenBlockTexts[i] == blocks[i]) {
        result.addAll(_frozenBlockWidgets[i]);
      } else {
        final w = buildInlineContent(blocks[i], widget.nc, context);
        if (i < _frozenBlockWidgets.length) {
          _frozenBlockWidgets[i] = w;
          _frozenBlockTexts[i] = blocks[i];
        } else {
          _frozenBlockWidgets.add(w);
          _frozenBlockTexts.add(blocks[i]);
        }
        result.addAll(w);
      }
    }
    final last = blocks.last;
    if (last.trim().isNotEmpty) {
      result.addAll(buildInlineContent(last, widget.nc, context));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final nc = widget.nc;
    if (msg.isError) {
      return _buildErrorCard(nc);
    }
    final steps = msg.steps;
    final hasSteps = steps != null && steps.isNotEmpty;
    final textContent = msg.cleanText;
    final isStreaming = msg.isStreaming;

    final showProcessLine = hasSteps || (isStreaming && textContent.isEmpty);

    // 流式期间使用增量富文本渲染：已完成块冻结缓存，仅重解析最后一个仍在
    // 生长的块。配合 ListenableBuilder 每帧最多重建一次（Flutter 调度合并多个
    // token 的 notifyListeners），单帧成本从「全量重解析整条 O(N)」降为
    // 「仅当前块 O(块大小)」，从而达成与 ChatGPT / DeepSeek 同级的边流边富文本
    // 流畅度。流结束后走下方整体规整一次（处理末块闭合等边界）。
    Widget textBody;
    if (isStreaming) {
      textBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _rebuildStreaming(textContent),
      );
    } else {
      if (textContent != _lastText) {
        _lastText = textContent;
        _cachedContent = buildInlineContent(textContent, nc, context);
        _frozenBlockWidgets.clear();
        _frozenBlockTexts.clear();
      }
      textBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _cachedContent,
      );
    }

    return FadeTransition(
      opacity: _enterOpacity,
      child: SlideTransition(
        position: _enterOffset,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showProcessLine)
            Padding(
              padding: EdgeInsets.only(bottom: textContent.isNotEmpty ? 8 : 0),
              child: _buildProcessLine(steps ?? const [], nc, msg.isStreaming),
            ),
          if (msg.plan != null)
            TaskPlanView(
              plan: msg.plan!,
              expanded: _planExpanded,
              onToggle: () => setState(() => _planExpanded = !_planExpanded),
            ),
          if (textContent.isNotEmpty) RepaintBoundary(child: textBody),
        ],
      ),
        ),
      ),
    );
  }

  /// 错误气泡：内联报错卡（浅红底 + 红图标 + 友好文案 + 重试）
  Widget _buildErrorCard(AgentColors nc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: nc.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: nc.error.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: nc.error),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.msg.text,
                    style: TextStyle(fontSize: 14, color: nc.textPrimary, height: 1.5),
                  ),
                  if (widget.onRetry != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: widget.onRetry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: nc.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '重试',
                          style: TextStyle(fontSize: 13, color: nc.error, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
          Icon(Icons.close, size: 16, color: nc.error),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                  fontSize: 15,
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

