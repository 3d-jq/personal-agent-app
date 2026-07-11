import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// 推入式抽屉（安全版 3D 推入，借鉴 Operit 但**不做 rotationY 翻转**）。
///
/// 抽屉固定在左侧底层，打开时主内容整体向右平移 + 轻微缩小 + 圆角 + 阴影，
/// 呈现「主内容被推到后面」的层次感。特点：
/// - **无遮罩**：不做半透明黑蒙层，主内容缩小后自身即形成视觉焦点；
/// - 打开用弹簧（轻微回弹），关闭用曲线（无回弹），贴近 Operit 手感；
/// - 支持左缘横滑开、内容区横滑/点击关。
///
/// 通过 [GlobalKey]<[PushDrawerState]> 调 open()/close()/toggle() 控制。
class PushDrawer extends StatefulWidget {
  final Widget drawer;
  final Widget child;
  final double drawerWidth;

  /// 抽屉打开状态变化回调（用于外部暂停自动滚动等）。
  final ValueChanged<bool>? onChanged;

  const PushDrawer({
    super.key,
    required this.drawer,
    required this.child,
    this.drawerWidth = 300,
    this.onChanged,
  });

  @override
  PushDrawerState createState() => PushDrawerState();
}

class PushDrawerState extends State<PushDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  bool _lastNotified = false;

  /// 主内容右移比例（相对抽屉宽度）：留出右侧一截主内容作为「卡片」。
  static const double _shiftFactor = 0.82;

  /// 主内容最小缩放（1.0 → 0.92）。
  static const double _minScale = 0.92;

  /// 主内容圆角与阴影最大值。
  static const double _maxRadius = 24;
  static const double _maxBlur = 18;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_maybeNotify);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _maybeNotify() {
    final open = _ac.value > 0.02;
    if (open != _lastNotified) {
      _lastNotified = open;
      widget.onChanged?.call(open);
    }
  }

  bool get isOpen => _ac.value > 0.5;

  /// 打开：弹簧（轻微回弹），贴近 Operit LowBouncy。
  void open() {
    _ac.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 320, damping: 26),
        _ac.value,
        1.0,
        _ac.velocity,
      ),
    );
  }

  /// 关闭：曲线（无回弹）。
  void close() {
    _ac.animateBack(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void toggle() => isOpen ? close() : open();

  void _onDragUpdate(DragUpdateDetails d) {
    _ac.value =
        (_ac.value + d.primaryDelta! / widget.drawerWidth).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() > 500) {
      v > 0 ? open() : close();
    } else {
      _ac.value > 0.5 ? open() : close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, _) {
        final p = _ac.value;
        final dx = p * widget.drawerWidth * _shiftFactor;
        final scale = 1 - p * (1 - _minScale);
        final radius = p * _maxRadius;

        return Stack(
          children: [
            // ── 抽屉层（左侧底层，随进度淡入 + 轻微放大/右移）──
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: widget.drawerWidth,
              child: Opacity(
                opacity: (p * 1.4).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset((1 - p) * -24, 0),
                  child: Transform.scale(
                    scale: 0.94 + 0.06 * p,
                    alignment: Alignment.centerLeft,
                    child: widget.drawer,
                  ),
                ),
              ),
            ),

            // ── 主内容层（右移 + 缩小 + 圆角 + 阴影）──
            Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.centerLeft,
                child: _buildMain(p, radius),
              ),
            ),

            // ── 关闭状态下的左缘抓取条：横滑拉出抽屉 ──
            if (p < 0.02)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 24,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMain(double p, double radius) {
    Widget main = widget.child;

    if (radius > 0.001) {
      main = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: main,
      );
      main = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18 * p),
              blurRadius: _maxBlur * p,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: main,
      );
    }

    // 打开时叠加透明层：点击空白/横滑关闭抽屉。
    if (p > 0.02) {
      main = Stack(
        children: [
          main,
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
            ),
          ),
        ],
      );
    }

    return main;
  }
}
