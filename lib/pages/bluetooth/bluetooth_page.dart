import 'package:flutter/material.dart';

import '../../bluetooth/serial_view_settings.dart';
import 'ble_serial_tab.dart';
import 'classic_serial_tab.dart';
import 'serial_settings_page.dart';

/// 蓝牙调试页：同一个页面里分两个页签，经典蓝牙串口和 BLE 串口。
///
/// 两者协议栈完全不同，分页而不是混在一个列表里，避免用户选错设备类型。
/// 右上角齿轮是这一层的子设置：切普通 / 自定义调试页、控制显示模块。
class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  // 两个页签共用一套显示配置
  final SerialViewSettings _settings = SerialViewSettings();

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            SerialSettingsPage(settings: _settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('蓝牙调试'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: '串口页设置',
              onPressed: _openSettings,
            ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(icon: Icon(Icons.settings_bluetooth), text: '经典串口'),
              Tab(icon: Icon(Icons.bluetooth_searching), text: 'BLE 串口'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            ClassicSerialTab(settings: _settings),
            BleSerialTab(settings: _settings),
          ],
        ),
      ),
    );
  }
}
