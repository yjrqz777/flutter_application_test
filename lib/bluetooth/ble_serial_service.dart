import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_uart_profile.dart';
import 'bluetooth_permissions.dart';
import 'serial_session.dart';

/// BLE 串口服务：把 BLE 透传当成一条串口来用。
///
/// 流程固定为：扫描 -> 连接 -> 发现服务 -> 挑出串口特征 -> 订阅通知 -> 收发。
/// 授权说明：flutter_blue_plus 对营利性使用要求购买商业授权，
/// 这里显式声明 [License.nonprofit]；商用请改成 License.commercial 并购买授权。
class BleSerialService extends SerialSession {
  static const License _license = License.nonprofit;
  static const Duration _scanDuration = Duration(seconds: 12);
  static const Duration _connectionTimeout = Duration(seconds: 15);

  final List<ScanResult> _results = <ScanResult>[];

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _scanningSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _valueSub;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;

  bool _scanning = false;
  bool _supported = true;

  /// 扫描结果，按信号强度从强到弱排好
  List<ScanResult> get results => List<ScanResult>.unmodifiable(_results);

  bool get isScanning => _scanning;

  bool get isSupported => _supported;

  /// 取设备显示名：没广播名字就退回设备 ID
  static String displayNameOf(ScanResult result) {
    final String name = result.device.platformName;
    return name.isEmpty ? result.device.remoteId.toString() : name;
  }

  /// 初始化：检查 BLE 支持情况并订阅扫描结果流。
  Future<void> init() async {
    try {
      _supported = await FlutterBluePlus.isSupported;
      if (!_supported) {
        setStatus('当前设备不支持 BLE');
        return;
      }
      _scanSub = FlutterBluePlus.onScanResults.listen(
        _onScanResults,
        onError: (Object error) => addSystem('扫描出错：$error'),
      );
      _scanningSub = FlutterBluePlus.isScanning.listen((bool value) {
        if (_scanning == value || isDisposed) return;
        _scanning = value;
        notifyListeners();
      });
      setStatus('点击「扫描设备」搜索 BLE 从机');
    } catch (error) {
      _supported = false;
      setStatus('BLE 初始化失败：$error');
    }
  }

  /// 开始扫描
  Future<void> startScan() async {
    if (_scanning || !_supported) return;

    if (!await BluetoothPermissions.ensure()) {
      setStatus('蓝牙权限被拒绝，请到系统设置里手动允许');
      return;
    }

    _results.clear();
    notifyListeners();
    setStatus('正在扫描 BLE 设备…');
    try {
      await FlutterBluePlus.startScan(timeout: _scanDuration);
    } catch (error) {
      setStatus('扫描失败：$error');
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // 停不下来不影响后续操作，忽略
    }
    _scanning = false;
    notifyListeners();
    setStatus('已停止扫描');
  }

  /// 连接指定设备，并把串口特征准备好。
  Future<void> connect(ScanResult result) async {
    if (_device != null || isBusy) return;

    final String name = displayNameOf(result);
    setBusy(true);
    try {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // 扫描已结束时 stopScan 可能报错，忽略
      }

      setStatus('正在连接 $name…');
      final BluetoothDevice device = result.device;
      _device = device;
      _connectionSub = device.connectionState.listen(
        (BluetoothConnectionState state) =>
            _onConnectionStateChanged(state, name),
      );

      await device.connect(license: _license, timeout: _connectionTimeout);

      final List<BluetoothService> services = await device.discoverServices();
      final BleUartCharacteristics characteristics =
          BleUartProfile.pick(services);
      _writeCharacteristic = characteristics.write;
      _notifyCharacteristic = characteristics.notify;

      if (characteristics.canReceive) {
        _valueSub = characteristics.notify!.onValueReceived.listen(
          (List<int> value) => addRx(Uint8List.fromList(value)),
        );
        await characteristics.notify!.setNotifyValue(true);
      }

      setConnected(true);
      if (characteristics.canSend) {
        setStatus('已连接 $name，可以收发数据了');
        addSystem('串口特征：写 ${characteristics.write!.uuid}'
            '${characteristics.canReceive ? '，收 ${characteristics.notify!.uuid}' : '，对端未开启通知'}');
      } else {
        setStatus('已连接 $name，但没找到可写入的特征，只能接收');
      }
    } catch (error) {
      await _cleanup();
      setStatus('连接失败：$error');
      addSystem('连接失败：$error');
    } finally {
      setBusy(false);
    }
  }

  /// 主动断开
  Future<void> disconnect() async {
    await _cleanup();
    setStatus('已断开连接');
  }

  @override
  Future<void> writeBytes(Uint8List bytes) async {
    final BluetoothCharacteristic? characteristic = _writeCharacteristic;
    if (characteristic == null) {
      throw StateError('没有找到可写入的串口特征');
    }

    // 一条 BLE 写最多能带 MTU - 3 字节，超长要按包拆开
    final bool withoutResponse =
        characteristic.properties.writeWithoutResponse &&
            !characteristic.properties.write;
    final int mtu = math.max(_device?.mtuNow ?? 23, 23);
    final int chunkSize = math.max(mtu - 3, 20);

    for (int offset = 0; offset < bytes.length; offset += chunkSize) {
      final int end = math.min(offset + chunkSize, bytes.length);
      await characteristic.write(
        bytes.sublist(offset, end),
        withoutResponse: withoutResponse,
      );
      if (withoutResponse && end < bytes.length) {
        // 无响应写的连续下发太快会丢包，隔一点时间
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  void _onScanResults(List<ScanResult> results) {
    if (isDisposed) return;
    _results
      ..clear()
      ..addAll(results)
      ..sort((ScanResult a, ScanResult b) => b.rssi.compareTo(a.rssi));
    notifyListeners();
  }

  void _onConnectionStateChanged(BluetoothConnectionState state, String name) {
    final bool connected = state == BluetoothConnectionState.connected;
    setConnected(connected);
    if (!connected && state == BluetoothConnectionState.disconnected) {
      _onRemoteDisconnected(name);
    }
  }

  void _onRemoteDisconnected(String name) {
    _device = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _valueSub?.cancel();
    _valueSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    setStatus('连接已断开（$name）');
    addSystem('BLE 连接断开：$name');
  }

  /// 释放连接资源（不改状态文案，调用方自己决定说什么）。
  Future<void> _cleanup() async {
    await _valueSub?.cancel();
    _valueSub = null;

    final BluetoothCharacteristic? notify = _notifyCharacteristic;
    if (notify != null) {
      try {
        await notify.setNotifyValue(false);
      } catch (_) {
        // 已经断开时取消订阅会抛异常，忽略
      }
    }

    await _connectionSub?.cancel();
    _connectionSub = null;

    final BluetoothDevice? device = _device;
    _device = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    setConnected(false);

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {
        // 已经断开时再断会抛异常，忽略
      }
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _scanningSub?.cancel();
    _valueSub?.cancel();
    _connectionSub?.cancel();
    final BluetoothDevice? device = _device;
    _device = null;
    device?.disconnect();
    super.dispose();
  }
}
