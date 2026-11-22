/// 应用基本信息：抽屉头部、主界面标题和「关于」页共用，改名字只改这里。
class AppInfo {
  AppInfo._();

  static const String appName = '多功能调试工具';
  static const String version = '0.0.1';
  static const String buildNumber = '1';
  static const String description =
      '面向硬件调试的桌面 / 移动工具：查看陀螺仪与姿态角，用经典蓝牙或 BLE 串口和板子收发数据。';

  /// 主要功能列表（关于页展示）
  static const List<String> features = <String>[
    '陀螺仪角速度实时显示',
    'Mahony 互补滤波融合姿态角（roll / pitch / yaw）',
    '经典蓝牙（SPP）串口收发调试',
    'BLE 低功耗串口（GATT 透传）收发调试',
    '普通 / 自定义两种串口调试页，显示模块可开关',
    '亮色 / 暗色主题切换',
  ];
}
