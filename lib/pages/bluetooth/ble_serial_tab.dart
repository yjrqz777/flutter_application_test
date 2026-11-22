import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../bluetooth/ble_serial_service.dart';
import '../../bluetooth/serial_view_settings.dart';
import '../../widgets/device_list_tile.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/serial_action_bar.dart';
import '../../widgets/serial_console.dart';

/// BLE 低功耗串口调试页。
///
/// 适配 HM-10、ESP32 BLE 透传这类从机：连上以后把 GATT 特征当串口用。
class BleSerialTab extends StatefulWidget {
  const BleSerialTab({super.key, required this.settings});

  /// 和经典蓝牙页签共用的显示配置
  final SerialViewSettings settings;

  @override
  State<BleSerialTab> createState() => _BleSerialTabState();
}

class _BleSerialTabState extends State<BleSerialTab>
    with AutomaticKeepAliveClientMixin {
  final BleSerialService _service = BleSerialService();

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
                      settings: widget.settings,
                      txBytes: _service.txBytes,
                      rxBytes: _service.rxBytes,
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
        title: '当前平台不支持 BLE',
        description: '需要手机或电脑本身带低功耗蓝牙硬件',
      );
    }
    if (_service.results.isEmpty) {
      return EmptyHint(
        title: _service.isScanning ? '正在扫描…' : '还没有找到设备',
        description: _service.isScanning
            ? 'BLE 从机需要处于广播状态，没连上别的手机'
            : '点击上方「扫描设备」搜索 HM-10、ESP32 BLE 等透传模块',
      );
    }
    return ListView.separated(
      itemCount: _service.results.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final ScanResult result = _service.results[index];
        return DeviceListTile(
          title: BleSerialService.displayNameOf(result),
          subtitle: '${result.device.remoteId} · ${result.rssi} dBm',
          onTap: () => _service.connect(result),
        );
      },
    );
  }
}
