import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

// flutter_blue_plus 也导出了一个 LogLevel（none/error/warning/info/debug/verbose），
// 和本地日志的 LogLevel 重名，这里把它的藏掉，只用本项目的那个
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;

import '../logging/app_log.dart';
import 'ble_uart_profile.dart';
import 'bluetooth_permissions.dart';
import 'serial_session.dart';
import 'uuid_text.dart';

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

  /// 连接时发现到的服务和特征，留着给「服务与特征」页展示和手动指定
  List<BluetoothService> _services = <BluetoothService>[];

  /// 本次扫描已经记过日志的设备，避免同一台设备刷满控制台
  final Set<String> _loggedDeviceIds = <String>{};

  /// 一次日志里最多列多少条服务和特征
  static const int _maxDiscoveryLines = 200;

  bool _scanning = false;
  bool _supported = true;

  /// 扫描结果，按信号强度从强到弱排好
  List<ScanResult> get results => List<ScanResult>.unmodifiable(_results);

  @override
  bool get isScanning => _scanning;

  @override
  bool get isSupported => _supported;

  @override
  String get logTag => 'BLE';

  /// 连接时发现到的全部服务和特征；没连上时是空列表
  List<BluetoothService> get services =>
      List<BluetoothService>.unmodifiable(_services);

  /// 当前用来发数据的特征
  BluetoothCharacteristic? get writeCharacteristic => _writeCharacteristic;

  /// 当前用来收通知的特征
  BluetoothCharacteristic? get notifyCharacteristic => _notifyCharacteristic;

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
      addSystem('BLE 初始化完成，准备就绪');
    } catch (error, stack) {
      _supported = false;
      setStatus('BLE 初始化失败：$error');
      addSystem('BLE 初始化异常', stack: '$stack');
    }
  }

  /// 开始扫描
  @override
  Future<void> startScan() async {
    if (_scanning || !_supported) return;

    if (!await BluetoothPermissions.ensure()) {
      setStatus('蓝牙权限被拒绝，请到系统设置里手动允许');
      return;
    }

    _results.clear();
    _loggedDeviceIds.clear();
    notifyListeners();
    setStatus('正在扫描 BLE 设备…');
    addSystem('开始扫描，超时 ${_scanDuration.inSeconds} 秒');
    try {
      await FlutterBluePlus.startScan(timeout: _scanDuration);
    } catch (error, stack) {
      setStatus('扫描失败：$error');
      addSystem('扫描异常', stack: '$stack');
    }
  }

  /// 停止扫描
  @override
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
      addSystem('开始连接：$name（${device.remoteId}），信号 ${result.rssi} dBm');
      _device = device;
      _connectionSub = device.connectionState.listen(
        (BluetoothConnectionState state) =>
            _onConnectionStateChanged(state, name),
      );

      await device.connect(license: _license, timeout: _connectionTimeout);
      addSystem('连接成功：$name（${device.remoteId}），当前 MTU ${device.mtuNow}');

      final List<BluetoothService> services = await device.discoverServices();
      _logDiscovery(services, device);
      final BleUartCharacteristics characteristics =
          BleUartProfile.pick(services);
      _services = services;
      _writeCharacteristic = characteristics.write;
      _notifyCharacteristic = characteristics.notify;

      if (characteristics.canReceive) {
        await _subscribeNotify();
      }

      setConnected(true);
      if (characteristics.canSend) {
        setStatus('已连接 $name，可以收发数据了');
        final String writeText = '写 ${formatUuid(characteristics.write!.uuid)}'
            '（${BleUartProfile.describeProperties(characteristics.write!.properties)}）';
        final String notifyText = characteristics.canReceive
            ? '，收 ${formatUuid(characteristics.notify!.uuid)}'
                '（${BleUartProfile.describeProperties(characteristics.notify!.properties)}）'
            : '，对端未开启通知';
        addSystem('串口特征：$writeText$notifyText');
      } else {
        setStatus('已连接 $name，但没找到可写入的特征，只能接收');
      }
    } catch (error, stack) {
      await _cleanup();
      setStatus('连接失败：$error');
      addSystem('连接异常', stack: '$stack');
    } finally {
      setBusy(false);
    }
  }

  /// 把发现到的服务和特征逐条记进日志，方便事后核对 UUID 和属性
  void _logDiscovery(List<BluetoothService> services, BluetoothDevice device) {
    final int characteristicCount = services.fold<int>(
      0,
      (int sum, BluetoothService service) => sum + service.characteristics.length,
    );
    addSystem('发现服务 ${services.length} 个、特征 $characteristicCount 条，'
        'MTU ${device.mtuNow}');

    int lines = 0;
    for (final BluetoothService service in services) {
      if (lines >= _maxDiscoveryLines) {
        addSystem('（服务和特征太多，剩下的没有逐条列出）');
        return;
      }
      addSystem('服务 ${formatUuid(service.uuid)}'
          '${service.isPrimary ? '' : '（次要）'}');
      lines++;
      for (final BluetoothCharacteristic characteristic
          in service.characteristics) {
        if (lines >= _maxDiscoveryLines) break;
        addSystem('  特征 ${formatUuid(characteristic.uuid)}'
            '（${BleUartProfile.describeProperties(characteristic.properties)}，'
            'id ${characteristic.instanceId}）');
        lines++;
      }
    }
  }

  /// 主动断开
  @override
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
    final int packets = (bytes.length + chunkSize - 1) ~/ chunkSize;

    AppLog.instance.add(
      LogLevel.info,
      LogKind.tx,
      logTag,
      '写入 ${bytes.length} 字节 → 特征 ${formatUuid(characteristic.uuid)}，MTU $mtu，'
      '每包 $chunkSize 字节共 $packets 包，'
      '${withoutResponse ? '无响应写' : '有响应写'}',
    );

    for (int offset = 0; offset < bytes.length; offset += chunkSize) {
      final int end = math.min(offset + chunkSize, bytes.length);
      final int packet = offset ~/ chunkSize + 1;
      try {
        await characteristic.write(
          bytes.sublist(offset, end),
          withoutResponse: withoutResponse,
        );
      } catch (error, stack) {
        AppLog.instance.add(
          LogLevel.error,
          LogKind.tx,
          logTag,
          '第 $packet/$packets 包写入失败（${end - offset} 字节）：$error',
          stack: '$stack',
        );
        rethrow;
      }
      if (withoutResponse && end < bytes.length) {
        // 无响应写的连续下发太快会丢包，隔一点时间
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  /// 手动指定发数据用的特征。
  ///
  /// 有些模块的数据通道不用 NUS / FFE1 那套 UUID，自动挑会挑错，
  /// 用户在「服务与特征」页点一下就能换成真正的那条。
  void selectWriteCharacteristic(BluetoothCharacteristic characteristic) {
    if (!isConnected) return;
    if (_writeCharacteristic == characteristic) return;
    _writeCharacteristic = characteristic;
    addSystem('改用特征发送：${formatUuid(characteristic.uuid)}'
        '（${BleUartProfile.describeProperties(characteristic.properties)}）');
    notifyListeners();
  }

  /// 手动指定收通知用的特征，换之前先把旧的通知订阅退掉。
  Future<void> selectNotifyCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    if (!isConnected || isBusy) return;
    if (_notifyCharacteristic == characteristic) return;

    setBusy(true);
    try {
      await _unsubscribeNotify();
      _notifyCharacteristic = characteristic;
      await _subscribeNotify();
      addSystem('改用特征接收：${formatUuid(characteristic.uuid)}'
          '（${BleUartProfile.describeProperties(characteristic.properties)}）');
    } catch (error, stack) {
      addSystem('切换接收特征失败：$error', stack: '$stack');
    } finally {
      setBusy(false);
    }
  }

  /// 订阅当前 notify 特征的通知
  Future<void> _subscribeNotify() async {
    final BluetoothCharacteristic? notify = _notifyCharacteristic;
    if (notify == null) return;
    _valueSub = notify.onValueReceived.listen(
      (List<int> value) => addRx(Uint8List.fromList(value)),
    );
    await notify.setNotifyValue(true);
  }

  /// 退掉当前 notify 特征的通知订阅
  Future<void> _unsubscribeNotify() async {
    await _valueSub?.cancel();
    _valueSub = null;

    final BluetoothCharacteristic? notify = _notifyCharacteristic;
    if (notify == null) return;
    try {
      await notify.setNotifyValue(false);
    } catch (_) {
      // 已经断开时取消订阅会抛异常，忽略
    }
  }

  void _onScanResults(List<ScanResult> results) {
    if (isDisposed) return;

    // 同一台设备会反复上报，只在第一次看到时记一条
    for (final ScanResult result in results) {
      final String id = result.device.remoteId.toString();
      if (_loggedDeviceIds.add(id)) {
        addSystem('发现设备：${displayNameOf(result)}（$id），'
            '信号 ${result.rssi} dBm');
      }
    }

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
      return;
    }
    if (!connected) {
      addSystem('连接状态变化：$name → ${state.name}');
    }
  }

  void _onRemoteDisconnected(String name) {
    _device = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _services = <BluetoothService>[];
    _valueSub?.cancel();
    _valueSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    setStatus('连接已断开（$name）');
  }

  /// 释放连接资源（不改状态文案，调用方自己决定说什么）。
  Future<void> _cleanup() async {
    await _unsubscribeNotify();

    await _connectionSub?.cancel();
    _connectionSub = null;

    final BluetoothDevice? device = _device;
    _device = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _services = <BluetoothService>[];
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
