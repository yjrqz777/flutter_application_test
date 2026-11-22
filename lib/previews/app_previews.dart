import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../app/theme_controller.dart';
import '../bluetooth/serial_message.dart';
import '../bluetooth/serial_view_settings.dart';
import '../pages/about_page.dart';
import '../pages/bluetooth/bluetooth_page.dart';
import '../pages/home_page.dart';
import '../pages/settings_page.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/serial_console.dart';

/// 界面预览入口：只给 IDE 的 Widget Preview 面板用，不参与正常启动。
///
/// 预览环境没有原生插件通道，传感器和蓝牙都取不到真实数据：
/// 页面结构能正常渲染，状态文案会停在「未连接 / 初始化失败」这类占位内容上。
const Size _pageSize = Size(390, 844);
const Size _panelSize = Size(390, 640);

/// 主页面（亮色）
@Preview(name: '主页面', group: '页面', size: _pageSize)
Widget previewHomePage() => MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: HomePage(title: 'Flutter', themeController: ThemeController()),
    );

/// 侧边菜单（抽屉完全展开的样子）
@Preview(name: '侧边菜单', group: '页面', size: Size(320, 720))
Widget previewSideMenu() => MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Row(
          children: <Widget>[AppDrawer(themeController: ThemeController())],
        ),
      ),
    );

/// 设置页
@Preview(name: '设置', group: '页面', size: _pageSize)
Widget previewSettingsPage() => MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: SettingsPage(themeController: ThemeController()),
    );

/// 关于页
@Preview(name: '关于', group: '页面', size: _pageSize)
Widget previewAboutPage() => MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const AboutPage(),
    );

/// 蓝牙调试页（两个页签的骨架）
@Preview(name: '蓝牙调试', group: '串口', size: _pageSize)
Widget previewBluetoothPage() => MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const BluetoothPage(),
    );

/// 串口控制台：普通调试页模板
@Preview(name: '控制台 · 普通', group: '串口', size: _panelSize)
Widget previewSerialConsoleNormal() => _consoleHost(SerialViewSettings());

/// 串口控制台：自定义调试页模板（快捷指令栏 + HEX 视图打开）
@Preview(name: '控制台 · 自定义', group: '串口', size: _panelSize)
Widget previewSerialConsoleCustom() {
  final SerialViewSettings settings = SerialViewSettings()
    ..setMode(SerialViewMode.custom)
    ..setShowQuickCommands(true);
  return _consoleHost(settings);
}

/// 把控制台套进一个带 AppBar 的页面里，方便单独看收发区
Widget _consoleHost(SerialViewSettings settings) {
  return MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      appBar: AppBar(title: const Text('串口控制台')),
      body: SerialConsole(
        messages: _demoMessages(),
        canSend: true,
        settings: settings,
        txBytes: 24,
        rxBytes: 96,
        onSend: (String text, bool hexMode) {},
        onClear: () {},
      ),
    ),
  );
}

/// 预览用的假数据：覆盖系统提示、文本收发和二进制收发
List<SerialMessage> _demoMessages() => <SerialMessage>[
      SerialMessage.system('已连接 HC-05（00:11:22:33:44:55）'),
      SerialMessage.tx(Uint8List.fromList('AT+GMR'.codeUnits)),
      SerialMessage.rx(
        Uint8List.fromList('AT version:1.2.3.0\r\nSDK version:3.0.4\r\nOK\r\n'.codeUnits),
      ),
      SerialMessage.tx(Uint8List.fromList(<int>[0x01, 0x0A, 0xFF])),
      SerialMessage.rx(Uint8List.fromList(<int>[0xAA, 0x55, 0x10, 0x20])),
      SerialMessage.rx(Uint8List.fromList('OK\r\n'.codeUnits)),
    ];
