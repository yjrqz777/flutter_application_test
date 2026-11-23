import 'package:flutter/material.dart';

import '../../bluetooth/ble_serial_service.dart';
import '../../bluetooth/classic_serial_service.dart';
import '../../bluetooth/serial_session.dart';
import '../../bluetooth/serial_view_settings.dart';
import '../../widgets/serial_action_bar.dart';
import 'ble_serial_tab.dart';
import 'classic_serial_tab.dart';
import 'serial_settings_page.dart';

/// 蓝牙调试页：经典蓝牙和 BLE 共用一套扫描 / 连接 / 控制台界面，
/// 用顶部的分段按钮切换当前模式。
///
/// 两种协议栈完全不同，设备对象也不一样，所以各自保留自己的会话对象；
/// 同一时刻只操作其中一种模式，避免两边的列表和连接状态混在一起。
class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  // 两种模式共用一套显示配置
  final SerialViewSettings _settings = SerialViewSettings();

  final ClassicSerialService _classic = ClassicSerialService();
  final BleSerialService _ble = BleSerialService();

  /// 开关状态：false = 经典蓝牙，true = BLE
  bool _bleMode = false;

  SerialSession get _session => _bleMode ? _ble : _classic;

  @override
  void initState() {
    super.initState();
    // 两边都先初始化好，切模式时不用等
    _classic.init();
    _ble.init();
  }

  @override
  void dispose() {
    _classic.dispose();
    _ble.dispose();
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

  /// 切模式：扫描中顺手停掉扫描；已连接或正在连接时不让切。
  Future<void> _switchMode(bool useBle) async {
    if (useBle == _bleMode) return;

    final SerialSession current = _session;
    if (current.isConnected || current.isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先断开当前连接，再切换模式')),
      );
      return;
    }

    if (current.isScanning) {
      await current.stopScan();
    }
    if (!mounted) return;
    setState(() => _bleMode = useBle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: const Text('蓝牙调试'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '串口页设置',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _session,
        builder: (BuildContext context, Widget? child) {
          final SerialSession session = _session;
          return Column(
            children: <Widget>[
              _buildModeBar(),
              SerialActionBar(
                status: session.status,
                connected: session.isConnected,
                scanning: session.isScanning,
                busy: session.isBusy,
                onScanToggle: session.isScanning
                    ? session.stopScan
                    : session.startScan,
                onDisconnect: session.disconnect,
              ),
              Expanded(
                child: _bleMode
                    ? BleSerialView(service: _ble, settings: _settings)
                    : ClassicSerialView(service: _classic, settings: _settings),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 模式切换：经典蓝牙 / BLE，顶部居中
  Widget _buildModeBar() {
    return SizedBox(
      height: 44,
      child: Center(
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.settings_bluetooth),
              label: Text('经典蓝牙'),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.bluetooth_searching),
              label: Text('BLE 蓝牙'),
            ),
          ],
          selected: <bool>{_bleMode},
          onSelectionChanged: (Set<bool> selection) =>
              _switchMode(selection.first),
        ),
      ),
    );
  }
}
