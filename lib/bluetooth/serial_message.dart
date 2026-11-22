import 'bytes_utils.dart';

/// 一条记录是发出去的、收回来的，还是系统提示。
enum SerialDirection { tx, rx, system }

/// 控制台里的一行记录。
///
/// 文本形式和 HEX 形式在创建时都算好，切换「HEX 视图」时不用重新解码。
class SerialMessage {
  const SerialMessage._({
    required this.direction,
    required this.time,
    required this.body,
    required this.hex,
    required this.byteCount,
  });

  /// 发送记录
  factory SerialMessage.tx(List<int> bytes) => SerialMessage._(
        direction: SerialDirection.tx,
        time: DateTime.now(),
        body: BytesUtils.describe(bytes),
        hex: BytesUtils.toHex(bytes),
        byteCount: bytes.length,
      );

  /// 接收记录
  factory SerialMessage.rx(List<int> bytes) => SerialMessage._(
        direction: SerialDirection.rx,
        time: DateTime.now(),
        body: BytesUtils.describe(bytes),
        hex: BytesUtils.toHex(bytes),
        byteCount: bytes.length,
      );

  /// 系统提示（连接、断开、错误等）
  factory SerialMessage.system(String text) => SerialMessage._(
        direction: SerialDirection.system,
        time: DateTime.now(),
        body: text,
        hex: '',
        byteCount: 0,
      );

  final SerialDirection direction;
  final DateTime time;

  /// 文本显示内容：可打印时是文本（换行显示成 \r \n 转义），否则是 HEX。
  final String body;

  /// HEX 显示内容；系统提示为空串。
  final String hex;

  /// 字节数，系统提示为 0。
  final int byteCount;

  /// 时分秒，列表左侧展示
  String get timeLabel {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
