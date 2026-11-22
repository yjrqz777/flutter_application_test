import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import '../../bluetooth/classic_serial_service.dart';
import '../../widgets/device_list_tile.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/serial_action_bar.dart';
import '../../widgets/serial_console.dart';

/// 经典蓝牙（RFCOMM / SPP）串口调试页。
///
/// 适配 HC-05 / HC-06 这类串口模块，也适配 ESP32 的经典蓝牙 BluetoothSerial。
class ClassicSerialTab extends StatefulWidget {
  const ClassicSerialTab({super.key});

  @override
  State<ClassicSerialTab> createState() => _ClassicSerialTabState();
}

class _ClassicSerialTabState extends State<ClassicSerialTab>
    with AutomaticKeepAliveClientMixin {
  final ClassicSerialService _service = ClassicSerialService();

  // 切到另一个页签时不销毁页面，避免正在进行的连接被重置
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _service.init();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: _service,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: <Widget>[
            SerialActionBar(
              status: _service.status,
              connected: _service.isConnected,
              scanning: _service.isScanning,
              busy: _service.isBusy,
              onScanToggle:
                  _service.isScanning ? _service.stopScan : _service.startScan,
              onDisconnect: _service.disconnect,
            ),
            Expanded(
              child: _service.isConnected
                  ? SerialConsole(
                      messages: _service.messages,
                      canSend: _service.canSend,
                      onSend: (String text, bool hexMode) =>
                          _service.sendText(text, hexMode: hexMode),
                      onClear: _service.clearMessages,
                    )
                  : _buildDeviceList(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceList(BuildContext context) {
    if (!_service.isSupported) {
      return const EmptyHint(
        icon: Icons.bluetooth_disabled,
        title: '当前平台不支持经典蓝牙串口',
        description: '经典蓝牙（SPP）需要 Android 手机，或带蓝牙适配器的 Windows 电脑',
      );
    }
    if (_service.devices.isEmpty) {
      return EmptyHint(
        title: _service.isScanning ? '正在扫描…' : '还没有找到设备',
        description: _service.isScanning
            ? '请让串口模块进入配对 / 可被发现状态'
            : '点击上方「扫描设备」搜索 HC-05、HC-06、ESP32 等经典蓝牙模块',
      );
    }
    return ListView.separated(
      itemCount: _service.devices.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final BtcDevice device = _service.devices[index];
        return DeviceListTile(
          title: device.displayName,
          subtitle: _subtitleOf(device),
          onTap: () => _service.connect(device),
        );
      },
    );
  }

  /// 地址 + 配对状态 + 信号强度
  String _subtitleOf(BtcDevice device) {
    final List<String> parts = <String>[
      device.address,
      device.bondState.name,
    ];
    if (device.rssi != null) {
      parts.add('${device.rssi} dBm');
    }
    return parts.join(' · ');
  }
}
