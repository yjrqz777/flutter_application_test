import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import 'bluetooth_permissions.dart';
import 'serial_session.dart';

/// 经典蓝牙（RFCOMM / SPP）串口服务。
///
/// 封装三件事：扫描设备、连上后收发字节、断开。页面只管调用和看状态。
class ClassicSerialService extends SerialSession {
  final FlutterClassicBluetooth _bluetooth = FlutterClassicBluetooth();

  final List<BtcDevice> _devices = <BtcDevice>[];

  /// 本次扫描已经记过日志的设备地址，避免同一台反复写
  final Set<String> _loggedAddresses = <String>{};

  StreamSubscription<BtcDevice>? _discoverySub;
  StreamSubscription<Uint8List>? _inputSub;
  StreamSubscription<BtcConnectionState>? _stateSub;
  BtcConnection? _connection;

  bool _scanning = false;
  bool _supported = true;

  /// 扫描到的设备 + 已配对设备（按地址去重合并）
  List<BtcDevice> get devices => List<BtcDevice>.unmodifiable(_devices);

  @override
  bool get isScanning => _scanning;

  @override
  bool get isSupported => _supported;

  @override
  String get logTag => '经典';

  /// 初始化：检查支持情况、读已配对设备、订阅扫描结果。
  Future<void> init() async {
    try {
      _supported = await _bluetooth.isSupported();
      if (!_supported) {
        setStatus('当前平台没有经典蓝牙：需要 Android 手机，或带蓝牙适配器的 Windows 电脑');
        return;
      }
      _discoverySub = _bluetooth.discoveryResults.listen(_onDeviceFound);
      final bool enabled = await _bluetooth.isEnabled();
      setStatus(enabled
          ? '蓝牙已开启，点击「扫描设备」搜索附近的串口模块'
          : '蓝牙未开启，请先在系统设置里打开蓝牙');
      addSystem('经典蓝牙初始化完成，蓝牙开关：${enabled ? '已开' : '未开'}');
      await _loadPairedDevices();
    } catch (error, stack) {
      _supported = false;
      setStatus('初始化失败：${_errorText(error)}');
      addSystem('经典蓝牙初始化异常', stack: '$stack');
    }
  }

  /// 开始扫描。Android 11 及以下扫描还需要打开系统定位开关，这里一并检查。
  @override
  Future<void> startScan() async {
    if (_scanning || !_supported) return;

    if (!await BluetoothPermissions.ensure()) {
      setStatus('蓝牙权限被拒绝，请到系统设置里手动允许');
      return;
    }
    if (await _bluetooth.isLocationServiceRequired() &&
        !await _bluetooth.isLocationServiceEnabled()) {
      setStatus('Android 11 及以下扫描需要打开系统定位开关，打开后重试');
      return;
    }

    _scanning = true;
    notifyListeners();
    setStatus('正在扫描附近设备…');
    _loggedAddresses.clear();
    addSystem('开始扫描经典蓝牙设备');
    try {
      await _bluetooth.startDiscovery();
    } catch (error, stack) {
      _scanning = false;
      notifyListeners();
      setStatus('扫描失败：${_errorText(error)}');
      addSystem('扫描异常', stack: '$stack');
    }
  }

  /// 停止扫描
  @override
  Future<void> stopScan() async {
    if (!_scanning) return;
    try {
      await _bluetooth.stopDiscovery();
    } catch (_) {
      // 停不下来不影响后续操作，忽略
    }
    _scanning = false;
    notifyListeners();
    setStatus('已停止扫描');
  }

  /// 连接指定设备。
  Future<void> connect(BtcDevice device) async {
    if (_connection != null || isBusy) return;

    setBusy(true);
    try {
      await stopScan();
      setStatus('正在连接 ${device.displayName}…');
      addSystem('开始连接：${device.displayName}（${device.address}）');
      final BtcConnection connection =
          await _bluetooth.connect(address: device.address);

      _connection = connection;
      _inputSub = connection.input.listen(addRx);
      _stateSub = connection.stateStream.listen((BtcConnectionState state) {
        if (state == BtcConnectionState.disconnected) {
          _onRemoteDisconnected(device.displayName);
        }
      });

      setConnected(true);
      setStatus('已连接 ${device.displayName}（${device.address}）');
    } catch (error, stack) {
      await _cleanup(silent: true);
      setStatus('连接失败：${_errorText(error)}');
      addSystem('连接异常', stack: '$stack');
    } finally {
      setBusy(false);
    }
  }

  /// 主动断开
  @override
  Future<void> disconnect() async {
    await _cleanup(silent: true);
    setStatus('已断开连接');
  }

  @override
  Future<void> writeBytes(Uint8List bytes) async {
    final BtcConnection? connection = _connection;
    if (connection == null) throw StateError('连接已断开');
    await connection.output.add(bytes);
  }

  /// 读系统里已配对的设备，省得每次都要扫描。
  Future<void> _loadPairedDevices() async {
    try {
      final List<BtcDevice> paired = await _bluetooth.getPairedDevices();
      for (final BtcDevice device in paired) {
        _mergeDevice(device);
      }
      addSystem('读取到 ${paired.length} 台已配对设备');
      notifyListeners();
    } catch (error, stack) {
      addSystem('读取已配对设备失败：${_errorText(error)}', stack: '$stack');
    }
  }

  void _onDeviceFound(BtcDevice device) {
    _mergeDevice(device);
    if (_loggedAddresses.add(device.address)) {
      addSystem('发现设备：${device.displayName}（${device.address}）');
    }
    notifyListeners();
  }

  /// 扫描结果和已配对列表会重复上报同一台设备，按地址合并。
  void _mergeDevice(BtcDevice device) {
    final int index =
        _devices.indexWhere((BtcDevice item) => item.address == device.address);
    if (index >= 0) {
      _devices[index] = _devices[index].mergedWith(device);
    } else {
      _devices.add(device);
    }
  }

  void _onRemoteDisconnected(String name) {
    _connection = null;
    _inputSub?.cancel();
    _inputSub = null;
    _stateSub?.cancel();
    _stateSub = null;
    setConnected(false);
    setStatus('连接已断开（$name）');
    addSystem('设备断开：$name');
  }

  /// 释放连接相关的资源；silent 为 true 时不动状态文案。
  Future<void> _cleanup({required bool silent}) async {
    final BtcConnection? connection = _connection;
    _connection = null;

    await _inputSub?.cancel();
    _inputSub = null;
    await _stateSub?.cancel();
    _stateSub = null;

    setConnected(false);
    if (connection != null) {
      try {
        await connection.finish();
      } catch (_) {
        // 已经断开时 finish 会抛异常，忽略
      }
      connection.dispose();
    }
    if (!silent) setStatus('已断开连接');
  }

  /// 插件抛的是 BtcException 的子类，取 message；其他异常直接转字符串。
  String _errorText(Object error) =>
      error is BtcException ? error.message : '$error';

  @override
  void dispose() {
    _discoverySub?.cancel();
    _inputSub?.cancel();
    _stateSub?.cancel();
    final BtcConnection? connection = _connection;
    _connection = null;
    connection?.dispose();
    super.dispose();
  }
}
