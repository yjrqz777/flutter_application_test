import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

/// 蓝牙运行时权限的申请入口。
///
/// 为什么复用经典蓝牙插件：它在自己的 AndroidManifest 里已经声明了
/// BLUETOOTH_SCAN / BLUETOOTH_CONNECT，并自带 checkPermissions()；
/// BLE 插件（flutter_blue_plus）只声明权限、不负责弹窗，
/// 两套用的是同一份系统权限，所以这里统一走经典蓝牙插件的接口，
/// 避免再引入一个额外依赖。
class BluetoothPermissions {
  BluetoothPermissions._();

  static final FlutterClassicBluetooth _bluetooth = FlutterClassicBluetooth();

  /// 确保扫描 + 连接权限已拿到；返回 false 表示用户拒绝。
  ///
  /// 桌面平台（Windows / Linux / macOS）在编译期就决定权限，
  /// 查询会返回 notRequired 或直接切异常，都按「允许」处理。
  static Future<bool> ensure() async {
    try {
      final BtcPermissionStatus current = await _bluetooth.checkPermissions();
      if (_isGranted(current)) return true;
      if (current == BtcPermissionStatus.permanentlyDenied) return false;
      final BtcPermissionStatus result = await _bluetooth.requestPermissions();
      return _isGranted(result);
    } catch (_) {
      return true;
    }
  }

  static bool _isGranted(BtcPermissionStatus status) =>
      status == BtcPermissionStatus.granted ||
      status == BtcPermissionStatus.notRequired;
}
