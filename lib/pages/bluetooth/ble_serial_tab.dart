import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../bluetooth/ble_serial_service.dart';
import '../../bluetooth/serial_view_settings.dart';
import '../../widgets/device_list_tile.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/serial_console.dart';

/// BLE 低功耗串口模式的内容区。
///
/// 扫描按钮和模式开关由蓝牙调试页统一管理，这里只按当前状态画：
/// 没连上时画设备列表，连上后画串口控制台。
class BleSerialView extends StatelessWidget {
  const BleSerialView({
    super.key,
    required this.service,
    required this.settings,
  });

  /// BLE 会话，由页面持有和初始化
  final BleSerialService service;

  /// 和经典蓝牙模式共用的显示配置
  final SerialViewSettings settings;

  @override
  Widget build(BuildContext context) {
    if (service.isConnected) {
      return SerialConsole(
        messages: service.messages,
        canSend: service.canSend,
        settings: settings,
        txBytes: service.txBytes,
        rxBytes: service.rxBytes,
        onSend: (String text, bool hexMode) =>
            service.sendText(text, hexMode: hexMode),
        onClear: service.clearMessages,
      );
    }
    return _buildDeviceList(context);
  }

  Widget _buildDeviceList(BuildContext context) {
    if (!service.isSupported) {
      return const EmptyHint(
        icon: Icons.bluetooth_disabled,
        title: '当前平台不支持 BLE',
        description: '需要手机或电脑本身带低功耗蓝牙硬件',
      );
    }
    if (service.results.isEmpty) {
      return EmptyHint(
        title: service.isScanning ? '正在扫描…' : '还没有找到设备',
        description: service.isScanning
            ? 'BLE 从机需要处于广播状态，没连上别的手机'
            : '点击上方「扫描设备」搜索 HM-10、ESP32 BLE 等透传模块',
      );
    }
    return ListView.separated(
      itemCount: service.results.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final ScanResult result = service.results[index];
        return DeviceListTile(
          title: BleSerialService.displayNameOf(result),
          subtitle: '${result.device.remoteId} · ${result.rssi} dBm',
          onTap: () => service.connect(result),
        );
      },
    );
  }
}
