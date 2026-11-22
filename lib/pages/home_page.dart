import 'package:flutter/material.dart';

import '../app/app_info.dart';
import '../app/theme_controller.dart';
import '../widgets/app_drawer.dart';
import 'about_page.dart';
import 'bluetooth/bluetooth_page.dart';
import 'test_page.dart';

/// 主界面：中间放几个悬浮按钮，分别进入 test、蓝牙调试、关于。
///
/// 左上角菜单仍然打开抽屉（设置、关于、蓝牙调试），
/// 原来的传感器 / 计数器页面移到了 [TestPage]，从这里进入。
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

  void _open(Widget page) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _EntryButton(
              icon: Icons.science_outlined,
              label: 'test',
              onTap: () => _open(TestPage(themeController: widget.themeController)),
            ),
            const SizedBox(height: 20),
            _EntryButton(
              icon: Icons.bluetooth,
              label: '蓝牙调试',
              onTap: () => _open(const BluetoothPage()),
            ),
            const SizedBox(height: 20),
            _EntryButton(
              icon: Icons.info_outline,
              label: '关于',
              onTap: () => _open(const AboutPage()),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主界面中间的入口按钮：带阴影的圆角块，视觉上浮在背景上
class _EntryButton extends StatelessWidget {
  const _EntryButton({
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
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: colorScheme.primaryContainer,
      shadowColor: colorScheme.shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 220,
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
