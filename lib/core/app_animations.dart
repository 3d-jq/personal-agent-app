import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';

/// 统一动画时长 token（Material 3）
class AppDurations {
  AppDurations._();

  /// 快速：按钮点击反馈、微交互（200ms，MD3 标准）
  static const fast = Duration(milliseconds: 200);

  /// 标准：页面转场、列表项出现、展开收起（300ms）
  static const standard = Duration(milliseconds: 300);

  /// Sheet 弹出（350ms）
  static const sheet = Duration(milliseconds: 350);

  /// 消息气泡入场（300ms，弹簧）
  static const bubble = Duration(milliseconds: 300);

  /// 慢速（500ms）
  static const slow = Duration(milliseconds: 500);

  /// 骨架屏闪烁（1500ms 循环）
  static const shimmer = Duration(milliseconds: 1500);

  /// 弹簧动效（250ms）
  static const expressive = Duration(milliseconds: 250);
}

/// 统一动画曲线 token
class AppCurves {
  AppCurves._();

  static const appear = Curves.easeOut;
  static const disappear = Curves.easeIn;
  static const state = Curves.easeInOut;
  static const page = Curves.easeInOut;
  static const color = Curves.easeInOut;

  // ── 兼容旧代码 ──
  static const press = Curves.easeOut;
  static const expand = Curves.easeInOut;
}

/// Material 3 Expressive 弹簧参数
class ExpressiveSpring {
  ExpressiveSpring._();

  /// Expressive 弹簧：明显回弹，按钮反馈、消息入场
  static final SpringDescription expressive = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 15.0,
  );

  /// Standard 弹簧：平滑自然，页面转场
  static final SpringDescription standard = SpringDescription(
    mass: 1.0,
    stiffness: 200.0,
    damping: 25.0,
  );

  /// 微弱弹簧：微交互，几乎无回弹
  static final SpringDescription subtle = SpringDescription(
    mass: 1.0,
    stiffness: 400.0,
    damping: 30.0,
  );
}

/// 按压缩放包装器（Expressive 弹簧全程）
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _springTo(double target) {
    _ctrl
      ..duration = AppDurations.expressive
      ..animateWith(
        SpringSimulation(
          ExpressiveSpring.subtle,
          _ctrl.value,
          target,
          _ctrl.velocity,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _springTo(widget.scale),
      onTapUp: (_) {
        _springTo(1.0);
        widget.onTap?.call();
      },
      onTapCancel: () => _springTo(1.0),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: _ctrl.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// 页面转场：iOS 横向滑入 + 旧页视差左移 + 右边缘滑动返回手势。
///
/// 基于 [CupertinoPageRoute]，**刻意不做整页 fade**——整页 opacity 淡入会让引擎
/// 在转场的每一帧对整页离屏合成（saveLayer/OpacityLayer），页面越复杂越贵，
/// 是「逻辑不卡但视觉一顿一顿」的元凶。纯横向平移几乎零合成开销，转场顺滑，
/// 且自带原生边缘返回手势与视差。
///
/// 全项目页面跳转统一走此路由（经由 AppRouter），改这一处即全局生效。
class IosSlideRoute<T> extends CupertinoPageRoute<T> {
  IosSlideRoute({required Widget page}) : super(builder: (_) => page);
}

/// BottomSheet 转场：从底部滑入 + 淡入（350ms，进出对称）
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpRoute({required this.page})
    : super(
        transitionDuration: AppDurations.sheet,
        reverseTransitionDuration: AppDurations.sheet,
        pageBuilder: (_, __, ___) => page,
        opaque: false,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}
