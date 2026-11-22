import 'package:flutter/material.dart';

/// 全应用统一的页面转场：淡入 + 轻微上滑。
///
/// 为什么换掉默认转场：Material 3 默认的 Zoom 转场会把整页内容缩放重采样，
/// 桌面和低端安卓上看着发虚、发顿；纯淡入配一点位移更跟手，结束也更干脆。
///
/// 用 [Animation.drive] 而不是 CurvedAnimation，避免每次 build 新建监听器。
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  /// 进入 260ms、退出 200ms，比默认的 300ms 更利落
  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 首屏启动时不做转场
    if (route.isFirst) return child;

    final Animation<double> fade = animation.drive(
      CurveTween(curve: Curves.easeOutCubic),
    );
    final Animation<Offset> slide = animation.drive(
      Tween<Offset>(
        begin: const Offset(0, 0.035),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
