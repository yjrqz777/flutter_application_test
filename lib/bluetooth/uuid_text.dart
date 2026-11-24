import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// UUID 在界面和日志里的显示格式。
///
/// 16 位短 UUID（蓝牙标准里那种，例：0010、fe95）本质是十六进制数，
/// 前面补 0x 更清楚；128 位完整 UUID 本身已经是带连字符的十六进制串，
/// 再加 0x 反而更难读，所以原样显示。
String formatUuid(Guid uuid) {
  final String text = uuid.toString();
  return text.length <= 4 ? '0x$text' : text;
}
