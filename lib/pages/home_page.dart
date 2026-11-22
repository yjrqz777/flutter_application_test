import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_info.dart';
import '../app/theme_controller.dart';
import '../widgets/app_drawer.dart';
import 'about_page.dart';
import 'bluetooth/bluetooth_page.dart';
import 'test_page.dart';

/// 主界面：中间一个圆形主按钮，点开以后 test、蓝牙调试、关于三个入口
/// 从中心呈放射状展开。
///
/// 左上角菜单仍然打开抽屉（设置、关于、蓝牙调试），
/// 原来的传感器 / 计数器页面移到了 [TestPage]，从 test 入口进入。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.themeController});

  /// 主题状态：这里和设置页共用同一个对象
  final ThemeController themeController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // 抽屉要用 ScaffoldState 打开，所以给 Scaffold 挂一个 key
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// 展开 / 收起的动画进度：0 全收，1 全开
  late final AnimationController _expand = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  /// 入口圆心的展开半径（像素）
  static const double _radius = 96;

  /// 三个入口分布的角度（度）：正上方、右下、左下
  static const double _angleTest = -90;
  static const double _angleBluetooth = 30;
  static const double _angleAbout = 150;

  @override
  void dispose() {
    _expand.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_expand.isCompleted || _expand.status == AnimationStatus.forward) {
      _expand.reverse();
    } else {
      _expand.forward();
    }
  }

  void _open(Widget page) {
    _expand.reverse();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(themeController: widget.themeController),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: '打开菜单',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(AppInfo.appName),
        actions: <Widget>[
          IconButton(
            // 切换主题：当前主题决定图标显示成“太阳”还是“月亮”
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: '切换主题',
            onPressed: widget.themeController.toggle,
          ),
        ],
      ),
      body: Center(
        child: SizedBox(
          width: 320,
          height: 320,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              _buildEntry(
                icon: Icons.science_outlined,
                label: 'test',
                angleDegrees: _angleTest,
                onTap: () => _open(
                  TestPage(themeController: widget.themeController),
                ),
              ),
              _buildEntry(
                icon: Icons.bluetooth,
                label: '蓝牙调试',
                angleDegrees: _angleBluetooth,
                onTap: () => _open(const BluetoothPage()),
              ),
              _buildEntry(
                icon: Icons.info_outline,
                label: '关于',
                angleDegrees: _angleAbout,
                onTap: () => _open(const AboutPage()),
              ),
              _buildCenterButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 中间的主按钮：点击展开 / 收起，图标在展开时转成关闭
  Widget _buildCenterButton(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.primary,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _toggle,
        child: SizedBox(
          width: 64,
          height: 64,
          child: RotationTransition(
            turns: Tween<double>(begin: 0, end: 0.125).animate(
              CurvedAnimation(parent: _expand, curve: Curves.easeOutCubic),
            ),
            child: Icon(Icons.add, size: 28, color: colorScheme.onPrimary),
          ),
        ),
      ),
    );
  }

  /// 一个放射状入口：按角度和进度算出位移
  Widget _buildEntry({
    required IconData icon,
    required String label,
    required double angleDegrees,
    required VoidCallback onTap,
  }) {
    final double radians = angleDegrees * math.pi / 180;
    final Offset target = Offset(
      math.cos(radians) * _radius,
      math.sin(radians) * _radius,
    );

    return AnimatedBuilder(
      animation: _expand,
      builder: (BuildContext context, Widget? child) {
        final double progress =
            Curves.easeOutCubic.transform(_expand.value.clamp(0.0, 1.0));
        return Transform.translate(
          offset: target * progress,
          child: Opacity(
            opacity: progress,
            child: IgnorePointer(
              ignoring: progress < 0.5,
              child: child,
            ),
          ),
        );
      },
      child: _EntryCircle(icon: icon, label: label, onTap: onTap),
    );
  }
}

/// 放射状展开出来的单个入口：圆形按钮 + 下方文字
class _EntryCircle extends StatelessWidget {
  const _EntryCircle({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerHighest,
              ),
              child: Icon(icon, size: 22, color: colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
