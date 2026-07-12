import 'package:flutter/material.dart';

import '../core/agent_colors.dart';
import '../core/app_animations.dart';

/// 会话列表加载骨架屏：模拟左右气泡形状 + 微光扫过，替代「点开会话」时的空白突兀感。
///
/// 配合 [ChatScreen] 的 loading 态：initialize 完成前显示，完成后淡入真实列表，
/// 把「转场动画帧」与「首屏气泡 build 帧」错峰，改善冷启动体感。
class ChatListSkeleton extends StatefulWidget {
  final int itemCount;
  /// 可选标签：传入时在骨架屏中央叠加「加载说明」（如「加载对话中」），
  /// 用于侧边栏切会话的延迟加载态；为 null 时保持纯气泡骨架。
  final String? label;
  const ChatListSkeleton({super.key, this.itemCount = 12, this.label});

  @override
  State<ChatListSkeleton> createState() => _ChatListSkeletonState();
}

class _ChatListSkeletonState extends State<ChatListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppDurations.shimmer,
  )..repeat();
  late final Animation<double> _anim = Tween<double>(begin: -1.0, end: 2.0).animate(
    CurvedAnimation(parent: _ctrl, curve: AppCurves.shimmer),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final highlight = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.65);
    final list = ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount,
      itemBuilder: (context, i) {
        final isUser = i.isOdd; // 左右交替，模拟对话
        return _SkeletonBubble(
          isUser: isUser,
          base: nc.bgSubtle,
          highlight: highlight,
          anim: _anim,
        );
      },
    );
    if (widget.label == null) return list;
    // 会话切换的「延迟加载」态：骨架屏中央叠加「加载说明」，告知用户正在加载对话。
    return Stack(
      children: [
        list,
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: nc.bgSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(nc.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.label!,
                  style: TextStyle(color: nc.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonBubble extends StatelessWidget {
  final bool isUser;
  final Color base;
  final Color highlight;
  final Animation<double> anim;
  const _SkeletonBubble({
    required this.isUser,
    required this.base,
    required this.highlight,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleWidth =
        MediaQuery.of(context).size.width * (isUser ? 0.5 : 0.66);
    final bubble = Container(
      height: 54,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(16),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: base,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: bubbleWidth,
            child: AnimatedBuilder(
              animation: anim,
              builder: (ctx, _) => ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [base, highlight, base],
                  stops: const [0.0, 0.5, 1.0],
                  transform: _SkeletonShimmerTransform(anim.value),
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: bubble,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonShimmerTransform extends GradientTransform {
  final double percent;
  const _SkeletonShimmerTransform(this.percent);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}
