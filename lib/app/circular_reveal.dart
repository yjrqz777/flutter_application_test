import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 从一个圆心向外扩散的页面转场。
///
/// 为什么单独做一个：主界面是放射状菜单，点入口时让页面也"从那个圆里长出来"，
/// 动效和菜单展开的方向连成一条线，比默认整页淡入更连贯。
///
/// [origin] 是全局坐标系里的扩散圆心（一般取被点按钮的中心）。
Route<T> circularRevealRoute<T>({
  required Widget page,
  required Offset origin,
}) {
  return PageRouteBuilder<T>(
    // 不透明路由会让下层页面停止绘制，圆形外就没有内容露出来，所以关掉
    opaque: false,
    transitionDuration: const Duration(milliseconds: 320),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? revealChild) {
        final Size size = MediaQuery.sizeOf(context);
        final double fullRadius = _radiusToFarthestCorner(origin, size);
        final double radius = fullRadius *
            Curves.easeOutCubic.transform(animation.value.clamp(0.0, 1.0));
        return ClipPath(
          clipper: _CircleClipper(center: origin, radius: radius),
          child: revealChild,
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
