import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

/// 陀螺仪数据服务：把底层的传感器订阅封装起来，对外只暴露一个事件流。
/// 好处：页面不需要关心订阅/取消订阅的细节，只管监听数据。
class GyroscopeService {
  StreamSubscription<GyroscopeEvent>? _sub;
  final StreamController<GyroscopeEvent> _controller =
      StreamController.broadcast();

  /// 对外暴露的事件流：每收到一帧陀螺仪数据，就发出一个事件。
  Stream<GyroscopeEvent> get events => _controller.stream;

  /// 开始监听陀螺仪（重复调用不会重复订阅）。
  void start() {
    if (_sub != null) return;
    _sub = gyroscopeEventStream().listen(_controller.add);
  }

  /// 停止监听。
  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  /// 释放资源（页面销毁时调用）。
  void dispose() {
    stop();
    _controller.close();
  }
}
