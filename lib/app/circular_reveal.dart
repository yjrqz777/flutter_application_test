import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 从一个圆心向外扩散的页面转场。
///
/// 为什么单独做一个：主界面是放射状菜单，点入口时让页面从那个圆里"长"出来，
/// 动效和菜单展开的方向连成一条线。
///
/// 三段合成，避免单纯的圆形硬擦除：
///   1. 圆形裁剪半径：easeOutQuart，起手快、收尾稳；
///   2. 页面整体淡入：只占前 55% 时间，画面不会到最后才跳出来；
///   3. 轻微放大 0.97 -> 1，让内容有"推近"的层次感。
///
/// [origin] 是全局坐标系里的扩散圆心（一般取被点按钮的中心）。
Route<T> circularRevealRoute<T>({
  required Widget page,
  required Offset origin,
}) {
  return PageRouteBuilder<T>(
    // 不透明路由会让下层页面停止绘制，圆形外就没有内容露出来，所以关掉
    opaque: false,
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) =>
        page,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) =>
        _CircleReveal(animation: animation, origin: origin, child: child),
  );
}

class _CircleReveal extends StatelessWidget {
  const _CircleReveal({
    required this.animation,
    required this.origin,
    required this.child,
  });

  final Animation<double> animation;
  final Offset origin;
  final Widget child;

  /// 淡入只占整段动画前 55% 的时间
  ///
  /// 注意：Interval 是 Curve（ParametricCurve），不是 Animatable，所以类型写 Curve。
  static const Interval _fadeInterval =
      Interval(0.0, 0.55, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      // builder 的 child 参数是可空的，这里直接用外层非空的 child，省掉判空
      builder: (BuildContext context, Widget? _) {
        final double progress = animation.value.clamp(0.0, 1.0);
        final Size size = MediaQuery.sizeOf(context);
        final double fullRadius = _radiusToFarthestCorner(origin, size);

        final double reveal = Curves.easeOutQuart.transform(progress);
        final double fade = _fadeInterval.transform(progress);
        final double scale = 0.97 + 0.03 * reveal;

        return ClipPath(
          clipper: _CircleClipper(center: origin, radius: fullRadius * reveal),
          child: Opacity(
            opacity: fade,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: child,
    );
  }

  /// 圆心到屏幕最远角的距离，保证动画结束时整页都被覆盖
  static double _radiusToFarthestCorner(Offset origin, Size size) {
    final double dx = math.max(origin.dx, size.width - origin.dx);
    final double dy = math.max(origin.dy, size.height - origin.dy);
    return math.sqrt(dx * dx + dy * dy) + 4;
  }
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..addOval(Rect.fromCircle(center: center, radius: math.max(radius, 0)));

  @override
  bool shouldReclip(_CircleClipper oldClipper) =>
      oldClipper.center != center || oldClipper.radius != radius;
}
