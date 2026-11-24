import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'standard_uuids.dart';

/// 蓝牙基数 UUID 的后半段：16 位 / 32 位 UUID 都套在这个模板上。
const String _baseUuidSuffix = '-0000-1000-8000-00805f9b34fb';

/// 取出查表用的键：16 位短 UUID 就是本身，套基数模板的 128 位写法也折回四位。
String _shortKey(Guid uuid) {
  final String text = uuid.toString().toLowerCase();
  if (text.length == 4) return text;
  if (text.length == 36 &&
      text.startsWith('0000') &&
      text.endsWith(_baseUuidSuffix)) {
    return text.substring(4, 8);
  }
  return text;
}

/// UUID 在界面和日志里的显示格式。
///
/// 16 位短 UUID（蓝牙标准里那种，例：0010、fe95）本质是十六进制数，
/// 前面补 0x 更清楚；128 位完整 UUID 本身已经是带连字符的十六进制串，
/// 再加 0x 反而更难读，所以原样显示。
String formatUuid(Guid uuid) {
  final String key = _shortKey(uuid);
  return key.length == 4 ? '0x$key' : uuid.toString();
}

/// 标准服务名，例如 0x1800 → Generic Access；不在表里就是 null。
String? serviceNameOf(Guid uuid) {
  final String key = _shortKey(uuid);
  return kStandardServiceNames[key] ?? kMemberServiceNames[key];
}

/// 标准特征名，例如 0x2a00 → Device Name；不在表里就是 null。
String? characteristicNameOf(Guid uuid) =>
    kStandardCharacteristicNames[_shortKey(uuid)];

/// 带名字的写法：`0x1800（Generic Access）`；没有标准名字时只给 `0xaf00`。
String labeledUuid(Guid uuid, String? name) =>
    name == null ? formatUuid(uuid) : '${formatUuid(uuid)}（$name）';
