import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_info.dart';
import '../app/circular_reveal.dart';
import '../app/theme_controller.dart';
import '../widgets/app_drawer.dart';
import 'about_page.dart';
import 'bluetooth/bluetooth_page.dart';
import 'test_page.dart';

/// 主界面：test、蓝牙调试、关于三个入口常驻显示，
/// 围绕中心排成一个三角形，点哪个就从那个圆的圆心展开对应页面。
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

class _HomePageState extends State<HomePage> {
  // 抽屉要用 ScaffoldState 打开，所以给 Scaffold 挂一个 key
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 入口布局的舞台，用来把入口的局部坐标换算成屏幕坐标
  final GlobalKey _menuKey = GlobalKey();

  /// 入口圆心到舞台中心的距离（像素）
  static const double _radius = 96;

  /// 入口布局舞台的尺寸
  static const Size _stageSize = Size(320, 320);

  /// 三个入口分布的角度（度）：正上方、右下、左下
  static const double _angleTest = -90;
  static const double _angleBluetooth = 30;
  static const double _angleAbout = 150;

  /// 打开入口页：页面从被点入口的圆心扩散展开。
  ///
  /// [localOrigin] 是该入口在舞台里的圆心坐标。
  void _open(Widget page, Offset localOrigin) {
    final RenderBox? menuBox =
        _menuKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset origin = menuBox != null && menuBox.hasSize
        ? menuBox.localToGlobal(localOrigin)
        : MediaQuery.sizeOf(context).center(Offset.zero);

    Navigator.of(context).push<void>(
      circularRevealRoute<void>(page: page, origin: origin),
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
          key: _menuKey,
          width: _stageSize.width,
          height: _stageSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              _buildEntry(
                icon: Icons.science_outlined,
                label: 'test',
                angleDegrees: _angleTest,
                page: TestPage(themeController: widget.themeController),
              ),
              _buildEntry(
                icon: Icons.bluetooth,
                label: '蓝牙调试',
                angleDegrees: _angleBluetooth,
                page: const BluetoothPage(),
              ),
              _buildEntry(
                icon: Icons.info_outline,
                label: '关于',
                angleDegrees: _angleAbout,
                page: const AboutPage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 一个入口：按角度摆在圆周上，点击后以自身位置为圆心展开页面
  Widget _buildEntry({
    required IconData icon,
    required String label,
    required double angleDegrees,
    required Widget page,
  }) {
    final double radians = angleDegrees * math.pi / 180;
    final Offset target = Offset(
      math.cos(radians) * _radius,
      math.sin(radians) * _radius,
    );
    final Offset localOrigin =
        Offset(_stageSize.width / 2, _stageSize.height / 2) + target;

    return Transform.translate(
      offset: target,
      child: _EntryCircle(
        icon: icon,
        label: label,
        onTap: () => _open(page, localOrigin),
      ),
    );
  }
}

/// 单个入口：圆形按钮 + 下方文字
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
