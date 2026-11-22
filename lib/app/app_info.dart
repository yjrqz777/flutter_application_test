/// 应用基本信息：抽屉头部和「关于」页共用，改版本号只改这里。
class AppInfo {
  AppInfo._();

  static const String appName = 'Flutter 调试工具';
  static const String version = '1.0.0+1';
  static const String description = '一个用来演示传感器数据采集和蓝牙串口调试的 Flutter 示例应用。';

  /// 主要功能列表（关于页展示）
  static const List<String> features = <String>[
    '陀螺仪角速度实时显示',
    'Mahony 互补滤波融合姿态角（roll / pitch / yaw）',
    '经典蓝牙（SPP）串口收发调试',
    'BLE 低功耗串口（GATT 透传）收发调试',
    '亮色 / 暗色主题切换',
  ];
}
