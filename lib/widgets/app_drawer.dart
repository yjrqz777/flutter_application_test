import 'package:flutter/material.dart';

import '../app/app_info.dart';
import '../app/theme_controller.dart';
import '../pages/about_page.dart';
import '../pages/bluetooth/bluetooth_page.dart';
import '../pages/log_page.dart';
import '../pages/settings_page.dart';

/// 从左侧滑出的主菜单：设置、关于、蓝牙调试。
///
/// 顺序按需求固定：第一项设置，第二项关于。
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _DrawerHeader(),
            const Divider(height: 1),
            // 功能区放上面，占满中间的剩余空间
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: <Widget>[
                  _DrawerItem(
                    icon: Icons.bluetooth,
                    title: '蓝牙调试',
                    subtitle: '经典蓝牙串口 / BLE 串口',
                    onTap: () => _open(context, const BluetoothPage()),
                  ),
                  _DrawerItem(
                    icon: Icons.terminal,
                    title: '控制台',
                    subtitle: '系统事件与收发日志',
                    onTap: () => _open(context, const LogPage()),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 设置、关于固定贴近底部
            _DrawerItem(
              icon: Icons.settings_outlined,
              title: '设置',
              onTap: () => _open(
                context,
                SettingsPage(themeController: themeController),
              ),
            ),
            _DrawerItem(
              icon: Icons.info_outline,
              title: '关于',
              onTap: () => _open(context, const AboutPage()),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 先关抽屉再进页面，避免返回时抽屉还开着
  void _open(BuildContext context, Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => page),
    );
  }
}

/// 抽屉顶部信息区
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.primaryContainer,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.developer_board,
            size: 36,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 12),
          Text(
            AppInfo.appName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'v${AppInfo.version}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}

/// 抽屉里的一项
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: onTap,
    );
  }
}
