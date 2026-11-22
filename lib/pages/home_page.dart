import 'package:flutter/material.dart';

import '../app/app_info.dart';
import '../app/circular_reveal.dart';
import '../app/theme_controller.dart';
import '../widgets/app_drawer.dart';
import 'about_page.dart';
import 'bluetooth/bluetooth_page.dart';
import 'test_page.dart';

/// 主界面：test、蓝牙调试、关于三个入口排成一行，
/// 点哪个就从那个圆的圆心展开对应页面。
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

  // 每个入口自己的 key：点击时用它取按钮中心的全局坐标，作为展开动画的圆心
  final GlobalKey _testKey = GlobalKey();
  final GlobalKey _bluetoothKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();

  /// 三个入口之间的间距
  static const double _gap = 32;

  /// 打开入口页：页面从被点按钮的圆心扩散展开。
  void _open(GlobalKey anchorKey, Widget page) {
    final RenderBox? anchor =
        anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset origin = anchor != null && anchor.hasSize
        ? anchor.localToGlobal(anchor.size.center(Offset.zero))
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _EntryCircle(
              key: _testKey,
              icon: Icons.science_outlined,
              label: 'test',
              onTap: () => _open(
                _testKey,
                TestPage(themeController: widget.themeController),
              ),
            ),
            const SizedBox(width: _gap),
            _EntryCircle(
              key: _bluetoothKey,
              icon: Icons.bluetooth,
              label: '蓝牙调试',
              onTap: () => _open(_bluetoothKey, const BluetoothPage()),
            ),
            const SizedBox(width: _gap),
            _EntryCircle(
              key: _aboutKey,
              icon: Icons.info_outline,
              label: '关于',
              onTap: () => _open(_aboutKey, const AboutPage()),
            ),
          ],
        ),
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
