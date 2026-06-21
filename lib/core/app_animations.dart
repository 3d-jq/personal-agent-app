import 'package:flutter/material.dart';

/// 统一动画时长 token
class AppDurations {
  AppDurations._();

  /// 快速：按压缩放、微交互、shimmer 起始
  static const fast = Duration(milliseconds: 150);

  /// 标准：页面转场、列表项出现、展开收起
  static const standard = Duration(milliseconds: 300);

  /// 慢速：主题切换、Hero 过渡、复杂动画
  static const slow = Duration(milliseconds: 500);
}

/// 统一动画曲线 token
class AppCurves {
  AppCurves._();

  /// 按压缩放
  static const press = Curves.easeOutCubic;

  /// 页面转场
  static const page = Curves.easeOutCubic;

  /// 展开收起
  static const expand = Curves.easeOutCubic;

  /// 颜色/主题过渡
  static const color = Curves.easeInOut;
}

/// 按压缩放包装器
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.95,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppDurations.fast);
    _anim = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: AppCurves.press),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Transform.scale(scale: _anim.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// 自定义页面转场：从右侧滑入 + 淡入
class SlideFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideFadeRoute({required this.page})
      : super(
          transitionDuration: AppDurations.standard,
          reverseTransitionDuration: AppDurations.standard,
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppCurves.page,
              reverseCurve: AppCurves.page,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// 自定义 BottomSheet 转场：从底部滑入 + 淡入
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpRoute({required this.page})
      : super(
          transitionDuration: AppDurations.standard,
          reverseTransitionDuration: AppDurations.standard,
          pageBuilder: (_, __, ___) => page,
          opaque: false,
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppCurves.page,
              reverseCurve: AppCurves.page,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
