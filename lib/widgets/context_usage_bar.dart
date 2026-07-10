import 'package:flutter/material.dart';
import '../core/agent_colors.dart';

/// 上下文窗口占用可视化（极简细条）。
///
/// 显示当前对话估算 token 占用 / 窗口大小，并在条上标出真实压缩阈值位置。
/// token 数为字符启发式估算（非真实分词），故条为「大致占用」指示。
///
/// 用法：外层用 `ListenableBuilder` 监听对应 controller，把三个取值传入即可。
class ContextUsageBar extends StatelessWidget {
  final int tokens;
  final int windowSize;
  final int threshold;
  final bool showLabel;
  final EdgeInsetsGeometry padding;

  const ContextUsageBar({
    super.key,
    required this.tokens,
    required this.windowSize,
    required this.threshold,
    this.showLabel = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  double get _ratio => windowSize > 0 ? tokens / windowSize : 0.0;
  double get _thresholdRatio => windowSize > 0 ? threshold / windowSize : 0.0;

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).round()}K' : '$n';

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final ratio = _ratio;
    final thresholdRatio = _thresholdRatio;

    // 颜色三态：绿（宽松）→ 琥珀（接近阈值）→ 红（到/过阈值）
    final Color fill = ratio >= thresholdRatio
        ? nc.error
        : ratio >= 0.6
            ? nc.warning
            : nc.success;

    final label = '${_fmt(tokens)} / ${_fmt(windowSize)}';

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth;
                final fillW = ratio.clamp(0.0, 1.0) * w;
                final markX = thresholdRatio.clamp(0.0, 1.0) * w;
                return Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: nc.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      child: Container(
                        width: fillW,
                        height: 4,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (markX > 0 && markX < w)
                      Positioned(
                        left: markX - 0.75,
                        child: Container(
                          width: 1.5,
                          height: 7,
                          color: nc.textPrimary.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: fill,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
