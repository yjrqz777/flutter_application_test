import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import '../../bluetooth/classic_serial_service.dart';
import '../../bluetooth/serial_view_settings.dart';
import '../../widgets/device_list_tile.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/serial_console.dart';

/// 经典蓝牙（RFCOMM / SPP）模式的内容区。
///
/// 扫描按钮和模式开关由蓝牙调试页统一管理，这里只按当前状态画：
/// 没连上时画设备列表，连上后画串口控制台。
class ClassicSerialView extends StatelessWidget {
  const ClassicSerialView({
    super.key,
    required this.service,
    required this.settings,
  });

  /// 经典蓝牙会话，由页面持有和初始化
  final ClassicSerialService service;

  /// 和 BLE 模式共用的显示配置
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
        title: '当前平台不支持经典蓝牙串口',
        description: '经典蓝牙（SPP）需要 Android 手机，或带蓝牙适配器的 Windows 电脑',
      );
    }
    if (service.devices.isEmpty) {
      return EmptyHint(
        title: service.isScanning ? '正在扫描…' : '还没有找到设备',
        description: service.isScanning
            ? '请让串口模块进入配对 / 可被发现状态'
            : '点击上方「扫描设备」搜索 HC-05、HC-06、ESP32 等经典蓝牙模块',
      );
    }
    return ListView.separated(
      itemCount: service.devices.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final BtcDevice device = service.devices[index];
        return DeviceListTile(
          title: device.displayName,
          subtitle: _subtitleOf(device),
          onTap: () => service.connect(device),
        );
      },
    );
  }

  /// 地址 + 配对状态 + 信号强度
  String _subtitleOf(BtcDevice device) {
    final List<String> parts = <String>[
      device.address,
      _bondStateLabel(device.bondState),
    ];
    if (device.rssi != null) {
      parts.add('${device.rssi} dBm');
    }
    return parts.join(' · ');
  }

  /// 已保存配对的设备标成「已配对」，其余状态也翻成中文
  String _bondStateLabel(BtcBondState state) => switch (state) {
    BtcBondState.bonded => '已配对',
    BtcBondState.bonding => '配对中',
    BtcBondState.none => '未配对',
  };
}
