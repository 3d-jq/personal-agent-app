import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/design_tokens.dart';

/// 统一轻提示（跟随主题 surface 的轻量卡片，替代散落 SnackBar）。
///
/// 替代散落的 `ScaffoldMessenger.showSnackBar`：圆角、轻阴影、淡入上滑、
/// 默认 2s 自动消失，并通过 root Overlay 渲染，避免依赖 Scaffold。
/// 复制 / 保存 / 错误等反馈全部统一走这里，保证全 App 反馈语言一致。
enum ToastType { success, error, info }

class AppToast {
  AppToast._();

  static OverlayEntry? _activeEntry;

  /// 在当前页面根部显示一个轻提示。
  ///
  /// [context] 任意有 Overlay 祖先的 context（通常来自 MaterialApp）。
  /// [type] 决定图标与强调色；[duration] 控制停留时长，默认 2s。
  /// 重复调用会先移除上一条，避免堆叠。
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    // 「完成时刻」：成功类提示附带一次轻量触觉反馈
    if (type == ToastType.success) HapticFeedback.lightImpact();
    _activeEntry?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        duration: duration,
        onDismissed: () {
          entry.remove();
          if (_activeEntry == entry) _activeEntry = null;
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }

  /// 立即移除当前提示（如页面将要离开时）。
  static void dismiss() {
    _activeEntry?.remove();
    _activeEntry = null;
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismissed;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
    Future.delayed(widget.duration, () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDismissed(), onError: (_) {});
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final (IconData icon, Color accent) = switch (widget.type) {
      ToastType.success => (Icons.check_circle_outline, nc.success),
      ToastType.error => (Icons.error_outline, nc.error),
      ToastType.info => (Icons.info_outline, nc.textSecondary),
    };
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).padding.bottom + 100,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _offset,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: nc.surface,
                  borderRadius: BorderRadius.circular(RadiusToken.md),
                  border: Border.all(
                    color: nc.divider.withValues(alpha: 0.6),
                    width: 0.5,
                  ),
                  boxShadow: nc.shadowMd,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: FontToken.body,
                          color: nc.textPrimary,
                          height: 1.4,
                        ),
                      ),
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
}
