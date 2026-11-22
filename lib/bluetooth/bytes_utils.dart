import 'dart:convert';

/// 字节流的显示与解析工具。
///
/// 串口数据既可能是文本（AT 指令），也可能是二进制（传感器帧），
/// 显示和输入两边都要在「文本」和「HEX」之间来回转换，统一放这里。
class BytesUtils {
  BytesUtils._();

  static const int _cr = 0x0D;
  static const int _lf = 0x0A;
  static const int _tab = 0x09;

  /// 是否全部是看得见的字符（可打印 ASCII，另加回车 / 换行 / 制表符）。
  static bool isPrintable(List<int> bytes) {
    for (final int byte in bytes) {
      if (byte == _cr || byte == _lf || byte == _tab) continue;
      if (byte < 0x20 || byte > 0x7E) return false;
    }
    return true;
  }

  /// 转成 HEX 字符串，例如 `01 0A FF`。
  static String toHex(List<int> bytes) {
    if (bytes.isEmpty) return '(空)';
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < bytes.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return buffer.toString();
  }

  /// 生成控制台里显示的内容：
  /// 能当文本看就显示文本，回车换行转成可见的转义字符；否则显示 HEX。
  static String describe(List<int> bytes) {
    if (bytes.isEmpty) return '(空)';
    if (!isPrintable(bytes)) return toHex(bytes);

    final StringBuffer buffer = StringBuffer();
    for (final int byte in bytes) {
      if (byte == _cr) {
        buffer.write(r'\r');
      } else if (byte == _lf) {
        buffer.write(r'\n');
      } else if (byte == _tab) {
        buffer.write(r'\t');
      } else {
        buffer.writeCharCode(byte);
      }
    }
    return buffer.toString();
  }

  /// 文本 -> 字节（UTF-8）。
  static List<int> encodeText(String input) => utf8.encode(input);

  /// HEX 文本 -> 字节，格式不对返回 null。
  ///
  /// 支持 `01 0A FF`、`01,0A,FF`、`0x01 0x0A`，以及不带分隔符的 `010AFF`。
  static List<int>? parseHex(String input) {
    final String text = input.replaceAll(RegExp(r'0[xX]'), ' ').trim();
    if (text.isEmpty) return const <int>[];

    final List<int> result = <int>[];
    final bool hasSeparator = RegExp(r'[\s,;]+').hasMatch(text);

    if (hasSeparator) {
      for (final String token in text.split(RegExp(r'[\s,;]+'))) {
        if (token.isEmpty) continue;
        final int? value = int.tryParse(token, radix: 16);
        if (value == null || value < 0 || value > 0xFF) return null;
        result.add(value);
      }
      return result;
    }

    // 没有分隔符时按两字符一组切，奇数长度直接判错
    if (text.length.isOdd) return null;
    for (int i = 0; i < text.length; i += 2) {
      final int? value = int.tryParse(text.substring(i, i + 2), radix: 16);
      if (value == null) return null;
      result.add(value);
    }
    return result;
  }
}
