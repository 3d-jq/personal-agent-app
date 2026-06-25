import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// 统一动画时长 token（Material 3 Expressive）
class AppDurations {
  AppDurations._();

  /// 快速：按钮点击反馈、微交互（100ms）
  static const fast = Duration(milliseconds: 100);

  /// 标准：页面转场、列表项出现、展开收起（300ms）
  static const standard = Duration(milliseconds: 300);

  /// Sheet 弹出（350ms）→ Expressive 延长至 400ms
  static const sheet = Duration(milliseconds: 400);

  /// 消息气泡入场（350ms，Expressive 弹簧）
  static const bubble = Duration(milliseconds: 350);

  /// 慢速：主题切换、Hero 过渡、复杂动画（500ms）
  static const slow = Duration(milliseconds: 500);

  /// 骨架屏闪烁（1500ms 循环）
  static const shimmer = Duration(milliseconds: 1500);

  /// FAB 展开 / 开关切换（250ms，Expressive 弹簧）
  static const expressive = Duration(milliseconds: 250);
}

/// 统一动画曲线 token（Material 3 Expressive）
class AppCurves {
  AppCurves._();

  /// 元素出现（进入屏幕）：easeOut
  static const appear = Curves.easeOut;

  /// 元素消失（离开屏幕）：easeIn
  static const disappear = Curves.easeIn;

  /// 状态变化（颜色、位置、大小）：easeInOut
  static const state = Curves.easeInOut;

  /// 页面转场
  static const page = Curves.easeInOut;

  /// 颜色/主题过渡
  static const color = Curves.easeInOut;

  // ── 兼容旧代码 ──
  static const press = Curves.easeOut;
  static const expand = Curves.easeInOut;
}

/// Material 3 Expressive 弹簧参数
class ExpressiveSpring {
  ExpressiveSpring._();

  /// Expressive 弹簧：明显回弹，用于按钮反馈、消息入场、FAB
  static final SpringDescription expressive = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 15.0,
  );

  /// Standard 弹簧：平滑自然，用于页面转场、列表项
  static final SpringDescription standard = SpringDescription(
    mass: 1.0,
    stiffness: 200.0,
    damping: 25.0,
  );
}

/// 按压缩放包装器（Expressive 弹簧回弹）
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
    _anim = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(_ctrl);
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
        // Expressive spring release — natural bounce back
        _ctrl
          ..duration = AppDurations.expressive
          ..animateWith(
            SpringSimulation(
              ExpressiveSpring.expressive,
              1.0, // from
              widget.scale, // to
              _ctrl.velocity,
            ),
          );
        widget.onTap?.call();
      },
      onTapCancel: () {
        _ctrl
          ..duration = AppDurations.expressive
          ..animateWith(
            SpringSimulation(
              ExpressiveSpring.expressive,
              1.0,
              widget.scale,
              _ctrl.velocity,
            ),
          );
      },
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) =>
            Transform.scale(scale: _anim.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// 自定义页面转场：从右侧滑入 + 淡入（Standard 弹簧）
class SlideFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideFadeRoute({required this.page})
    : super(
        transitionDuration: AppDurations.standard,
        reverseTransitionDuration: AppDurations.standard,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
      );
}

/// 自定义 BottomSheet 转场：从底部滑入 + 淡入（Expressive 弹簧，400ms）
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpRoute({required this.page})
    : super(
        transitionDuration: AppDurations.sheet,
        reverseTransitionDuration: AppDurations.standard,
        pageBuilder: (_, __, ___) => page,
        opaque: false,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
      );
}
