import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'bytes_utils.dart';
import 'serial_message.dart';

/// 串口会话基类：经典蓝牙和 BLE 共用的一套状态与交互。
///
/// 子类只需要实现 [writeBytes]（怎么把字节写出去）以及自己的连接流程，
/// 日志、连接状态、发送解析这些重复逻辑都留在基类里。
abstract class SerialSession extends ChangeNotifier {
  /// 日志上限：调试时数据刷得很快，不限制会一直占内存。
  static const int maxMessages = 500;

  final List<SerialMessage> _messages = <SerialMessage>[];
  bool _connected = false;
  bool _busy = false;
  bool _disposed = false;
  String _status = '正在初始化…';

  /// 控制台记录（最新的在列表末尾）
  List<SerialMessage> get messages => List<SerialMessage>.unmodifiable(_messages);

  /// 是否已连接到设备
  bool get isConnected => _connected;

  /// 是否正在扫描 / 连接（用来禁用按钮、显示进度）
  bool get isBusy => _busy;

  /// 顶部状态条上的一句话说明
  String get status => _status;

  /// 是否可以发送数据
  bool get canSend => _connected && !_busy;

  @protected
  bool get isDisposed => _disposed;

  @protected
  void setConnected(bool value) {
    if (_disposed || _connected == value) return;
    _connected = value;
    notifyListeners();
  }

  @protected
  void setBusy(bool value) {
    if (_disposed || _busy == value) return;
    _busy = value;
    notifyListeners();
  }

  @protected
  void setStatus(String value) {
    if (_disposed || _status == value) return;
    _status = value;
    notifyListeners();
  }

  /// 往控制台追加一条系统提示
  void addSystem(String text) => _append(SerialMessage.system(text));

  /// 往控制台追加一条接收记录
  @protected
  void addRx(Uint8List bytes) => _append(SerialMessage.rx(bytes));

  /// 清空控制台
  void clearMessages() {
    if (_disposed) return;
    _messages.clear();
    notifyListeners();
  }

  /// 发送一次输入：文本按 UTF-8 编码，HEX 按字节解析。
  Future<void> sendText(String input, {required bool hexMode}) async {
    if (!_connected) {
      addSystem('未连接，无法发送');
      return;
    }

    final List<int>? bytes =
        hexMode ? BytesUtils.parseHex(input) : BytesUtils.encodeText(input);
    if (bytes == null) {
      addSystem('HEX 格式不正确：$input');
      return;
    }
    if (bytes.isEmpty) {
      addSystem('内容为空，没有发送');
      return;
    }

    try {
      await writeBytes(Uint8List.fromList(bytes));
      _append(SerialMessage.tx(bytes));
    } catch (error) {
      addSystem('发送失败：$error');
    }
  }

  /// 子类实现：真正把字节写到远端设备。
  @protected
  Future<void> writeBytes(Uint8List bytes);

  void _append(SerialMessage message) {
    if (_disposed) return;
    _messages.add(message);
    if (_messages.length > maxMessages) {
      _messages.removeRange(0, _messages.length - maxMessages);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
