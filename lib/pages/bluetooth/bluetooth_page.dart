import 'package:flutter/material.dart';

import 'ble_serial_tab.dart';
import 'classic_serial_tab.dart';

/// 蓝牙调试页：同一个页面里分两个页签，经典蓝牙串口和 BLE 串口。
///
/// 两者协议栈完全不同，分页而不是混在一个列表里，避免用户选错设备类型。
class BluetoothPage extends StatelessWidget {
  const BluetoothPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('蓝牙调试'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(icon: Icon(Icons.settings_bluetooth), text: '经典串口'),
              Tab(icon: Icon(Icons.bluetooth_searching), text: 'BLE 串口'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            ClassicSerialTab(),
            BleSerialTab(),
          ],
        ),
      ),
    );
  }
}
