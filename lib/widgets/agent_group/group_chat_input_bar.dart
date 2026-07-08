import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../core/agent_colors.dart';
import '../../core/design_tokens.dart';
import '../../models/agent.dart';

/// 群聊底部输入栏：胶囊形输入框 + @ 召唤 + 发送 / 停止。
///
/// 通过 [controller] 的监听实时刷新发送按钮的可用态（有文本才高亮），
/// 因此本组件自行管理文本变化引起的局部重建，避免父级整体 rebuild。
class GroupChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final bool isCompressing;
  final List<Agent> members;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onMention;
  final double bottomSafe;

  const GroupChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.isCompressing,
    required this.members,
    required this.onSend,
    required this.onStop,
    required this.onMention,
    this.bottomSafe = 0,
  });

  @override
  State<GroupChatInputBar> createState() => _GroupChatInputBarState();
}

class _GroupChatInputBarState extends State<GroupChatInputBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    // 文本变化需要刷新发送按钮（启用态 / 颜色）
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final canSend = widget.controller.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpaceToken.lg,
                SpaceToken.xs,
                SpaceToken.lg,
                0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: nc.bgSubtle.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(RadiusToken.pill),
                  // Apple HIG：用 0.5px 边框代替阴影
                  border: Border.all(color: nc.divider, width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SpaceToken.lg,
                        SpaceToken.sm,
                        SpaceToken.lg,
                        SpaceToken.xs,
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: const InputDecorationTheme(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                        ),
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          minLines: 1,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          enabled: !widget.isCompressing && !widget.busy,
                          style: TextStyle(
                            fontSize: FontToken.body,
                            color: nc.textPrimary,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.isCompressing
                                ? '上下文压缩中...'
                                : widget.members.isEmpty
                                    ? '先把 Agent 拉进群再说'
                                    : '说点什么，@名字 来召唤 Agent',
                            hintStyle: TextStyle(
                              color: widget.isCompressing
                                  ? nc.primary
                                  : nc.textSecondary.withValues(alpha: 0.6),
                              fontSize: FontToken.body,
                              height: 1.5,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: SpaceToken.md),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SpaceToken.sm,
                        0,
                        SpaceToken.sm,
                        SpaceToken.sm,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onMention();
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: nc.surface,
                                borderRadius: BorderRadius.circular(RadiusToken.pill),
                              ),
                              child: Text(
                                '@',
                                style: TextStyle(
                                  fontSize: FontToken.body,
                                  fontWeight: FontWeight.w600,
                                  color: widget.members.isNotEmpty
                                      ? nc.textPrimary
                                      : nc.textDisabled,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (widget.busy) {
                                widget.onStop();
                              } else if (canSend) {
                                widget.onSend();
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: widget.busy
                                    ? nc.error.withValues(alpha: 0.1)
                                    : canSend
                                        ? nc.primary
                                        : nc.surface,
                                borderRadius: BorderRadius.circular(RadiusToken.pill),
                              ),
                              child: Icon(
                                widget.busy
                                    ? Icons.stop
                                    : Icons.arrow_upward,
                                size: 18,
                                color: widget.busy
                                    ? nc.error
                                    : canSend
                                        ? Colors.white
                                        : nc.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: SpaceToken.xs),
        Padding(
          padding: EdgeInsets.only(bottom: widget.bottomSafe + SpaceToken.xs),
          child: Text(
            '直接发消息，系统会自动调度 Agent',
            style: TextStyle(fontSize: FontToken.micro, color: nc.textDisabled),
          ),
        ),
      ],
    );
  }
}
