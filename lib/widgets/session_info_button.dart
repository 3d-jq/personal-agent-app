import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/app_router.dart';
import '../services/context_doc_service.dart';
import 'context_docs_panel.dart';
import 'context_usage_bar.dart';

/// 右上角「身份牌」按钮：点开后弹出会话信息面板。
///
/// 面板内包含：
///  - 上下文窗口占用（细条 + 数字 + 状态说明），按需查看、不常驻，避免界面突兀；
///  - 原有的文档/资料快捷入口（SOUL / USER / AGENT / AI 草稿纸）。
///
/// 上下文用量通过三个取值闭包传入，类型无关，单聊与群聊共用同一套。
class SessionInfoButton extends StatelessWidget {
  final int Function() getTokens;
  final int Function() getWindowSize;
  final int Function() getThreshold;
  final Listenable? listenable;

  const SessionInfoButton({
    super.key,
    required this.getTokens,
    required this.getWindowSize,
    required this.getThreshold,
    this.listenable,
  });

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => SessionInfoSheet.show(
          context,
          listenable: listenable,
          getTokens: getTokens,
          getWindowSize: getWindowSize,
          getThreshold: getThreshold,
        ),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.badge, size: 22, color: nc.textPrimary),
        ),
      ),
    );
  }
}

/// 会话信息底部面板。
class SessionInfoSheet {
  static Future<void> show(
    BuildContext context, {
    Listenable? listenable,
    required int Function() getTokens,
    required int Function() getWindowSize,
    required int Function() getThreshold,
  }) async {
    final nc = AgentColors.of(context);

    Widget buildContent() {
      final tokens = getTokens();
      final windowSize = getWindowSize();
      final threshold = getThreshold();
      final ratio = windowSize > 0 ? tokens / windowSize : 0.0;
      final thresholdRatio = windowSize > 0 ? threshold / windowSize : 0.0;
      final Color fill = ratio >= thresholdRatio
          ? nc.error
          : ratio >= 0.6
              ? nc.warning
              : nc.success;
      final String statusText = ratio >= thresholdRatio
          ? '接近压缩阈值，即将自动压缩'
          : ratio >= 0.6
              ? '占用较高，注意上下文长度'
              : '占用正常';
      // <1000 显示精确值；1000~99999 显示一位小数（几百 token 变化也可见）；
      // ≥100K 用整数避免过长。
      String fmt(int n) {
        if (n < 1000) return '$n';
        final k = n / 1000;
        return k >= 100 ? '${k.round()}K' : '${k.toStringAsFixed(1)}K';
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: nc.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '会话信息',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: nc.textPrimary,
              ),
            ),
          ),
          // ── 上下文窗口占用卡片 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: nc.primarySurface,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '上下文窗口占用',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: nc.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '约 ${fmt(tokens)} / ${fmt(windowSize)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: fill,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ContextUsageBar(
                    tokens: tokens,
                    windowSize: windowSize,
                    threshold: threshold,
                    showLabel: false,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  Text(statusText, style: TextStyle(fontSize: 12, color: fill)),
                  const SizedBox(height: 4),
                  Text(
                    '数值为估算值（非真实分词），占用约达 ${(thresholdRatio * 100).round()}% 时自动压缩',
                    style: TextStyle(fontSize: 11, color: nc.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          // ── 文档 / 资料快捷入口 ──
          ...ContextDoc.values
              .where((d) => d != ContextDoc.knowledge)
              .map((doc) => _docTile(
                    nc,
                    ContextDocViewerPage.iconFor(doc),
                    ContextDocViewerPage.titleFor(doc),
                    () => AppRouter.toContextDocViewer(context, doc: doc),
                  )),
          _docTile(
            nc,
            Icons.article,
            'AI 草稿纸',
            () => AppRouter.toScratchViewer(context),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    Widget content = buildContent();
    if (listenable != null) {
      content = ListenableBuilder(listenable: listenable, builder: (_, __) => buildContent());
    }
    // 用 SafeArea(top:false) 避开底部系统手势条，避免「AI 草稿纸」被手势条压住。
    content = SafeArea(top: false, child: content);

    return showModalBottomSheet(
      context: context,
      backgroundColor: nc.surface,
      // 允许面板按内容自适应高度：默认 false 时最大高度被限制在屏幕 9/16(约 56%)，
      // 内容超出会被裁剪，导致底部留白/「AI 草稿纸」被切掉、看起来永远贴底。
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => content,
    );
  }

  static Widget _docTile(
    AgentColors nc,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: nc.textPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 15, color: nc.textPrimary),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: nc.textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
