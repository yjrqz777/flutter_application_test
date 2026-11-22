import 'package:flutter/material.dart';

/// 扫描结果里的一行设备。
///
/// 经典蓝牙和 BLE 的设备对象类型不同，这里只接收拼好的字符串，
/// 两个页面共用同一套列表样式。
class DeviceListTile extends StatelessWidget {
  const DeviceListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.icon = Icons.bluetooth,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? trailing;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: trailing == null
          ? const Icon(Icons.chevron_right)
          : Text(trailing!),
      onTap: onTap,
    );
  }
}
