import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 一条 BLE 串口需要的两个特征：一个写出去，一个收通知。
///
/// 少数模块只有写或只有通知，所以两个字段都可空，用 [canSend] / [canReceive] 判断。
class BleUartCharacteristics {
  const BleUartCharacteristics({this.write, this.notify});

  final BluetoothCharacteristic? write;
  final BluetoothCharacteristic? notify;

  bool get canSend => write != null;

  bool get canReceive => notify != null;
}

/// BLE 串口的特征选择规则。
///
/// 不同模块各用各的 UUID 约定：
///   - Nordic UART Service（ESP32 Arduino / 自定义固件常见）：一写一通知；
///   - HM-10 / CC2541 透传：FFE1 一条特征同时可写可通知。
/// 都不匹配时退回「第一条可写 + 第一条可通知」，让私有固件也能调试。
class BleUartProfile {
  BleUartProfile._();

  static final Guid _nusWrite = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid _nusNotify = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid _uartCharacteristic =
      Guid('0000ffe1-0000-1000-8000-00805f9b34fb');

  /// 从发现到的服务里挑出串口用的特征。
  static BleUartCharacteristics pick(List<BluetoothService> services) {
    BluetoothCharacteristic? write;
    BluetoothCharacteristic? notify;

    for (final BluetoothService service in services) {
      for (final BluetoothCharacteristic characteristic
          in service.characteristics) {
        final Guid uuid = characteristic.uuid;
        final bool isKnown =
            uuid == _nusWrite || uuid == _nusNotify || uuid == _uartCharacteristic;
        if (!isKnown) continue;

        // NUS 的写特征不可通知、通知特征不可写，用 uuid 排除配对错误
        if (uuid != _nusNotify && _canWrite(characteristic)) {
          write ??= characteristic;
        }
        if (uuid != _nusWrite && _canNotify(characteristic)) {
          notify ??= characteristic;
        }
      }
    }

    write ??= _firstWhere(services, _canWrite);
    notify ??= _firstWhere(services, _canNotify);

    return BleUartCharacteristics(write: write, notify: notify);
  }

  static bool _canWrite(BluetoothCharacteristic characteristic) =>
      characteristic.properties.write ||
      characteristic.properties.writeWithoutResponse;

  static bool _canNotify(BluetoothCharacteristic characteristic) =>
      characteristic.properties.notify || characteristic.properties.indicate;

  static BluetoothCharacteristic? _firstWhere(
    List<BluetoothService> services,
    bool Function(BluetoothCharacteristic) test,
  ) {
    for (final BluetoothService service in services) {
      for (final BluetoothCharacteristic characteristic
          in service.characteristics) {
        if (test(characteristic)) return characteristic;
      }
    }
    return null;
  }
}
