import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/agent_colors.dart';

/// 统一的空态 / 加载态 / 错误态占位组件。
class StatePlaceholder extends StatelessWidget {
  final Widget? icon;
  final String? title;
  final String? subtitle;
  final bool loading;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const StatePlaceholder({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.loading = false,
    this.retryLabel,
    this.onRetry,
  });

  /// 通用空态：大图标 + 主标题 + 副标题。
  factory StatePlaceholder.empty({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
  }) => StatePlaceholder(
    key: key,
    icon: Icon(icon, size: 48),
    title: title,
    subtitle: subtitle,
  );

  /// 通用加载态：带可选提示文字。
  factory StatePlaceholder.loading({Key? key, String? message}) => StatePlaceholder(
    key: key,
    loading: true,
    title: message,
  );

  /// 通用错误态：警告图标 + 错误信息 + 重试按钮。
  factory StatePlaceholder.error({
    Key? key,
    String? title,
    String? subtitle,
    String retryLabel = '重试',
    required VoidCallback onRetry,
  }) => StatePlaceholder(
    key: key,
    icon: const Icon(PhosphorIconsRegular.warningCircle, size: 48),
    title: title ?? '出错了',
    subtitle: subtitle,
    retryLabel: retryLabel,
    onRetry: onRetry,
  );

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(nc.textSecondary),
              ),
            ),
          ] else if (icon != null) ...[
            IconTheme(
              data: IconThemeData(color: onRetry != null ? nc.error : nc.textSecondary.withValues(alpha: 0.3)),
              child: icon!,
            ),
          ],
          if (title != null && title!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              title!,
              style: TextStyle(
                fontSize: 15,
                color: onRetry != null ? nc.textPrimary : nc.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: nc.textSecondary.withValues(alpha: onRetry != null ? 0.6 : 0.4),
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(PhosphorIconsRegular.arrowsClockwise, size: 16, color: nc.primary),
              label: Text(retryLabel ?? '重试', style: TextStyle(color: nc.primary)),
            ),
          ],
        ],
      ),
    );
  }
}
