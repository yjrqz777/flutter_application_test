import 'package:flutter/foundation.dart';

/// 串口调试页的两种模板。
enum SerialViewMode {
  normal('普通调试页'),
  custom('自定义调试页');

  const SerialViewMode(this.label);

  final String label;
}

/// 串口调试页的显示配置。
///
/// 普通模式是固定模板：必须显示收发、收发字节计数和方向标签，
/// 只放开「时间戳」「字节计数」两个开关；
/// 自定义模式把方向标签、HEX 视图、快捷指令栏也交给用户自由开关。
class SerialViewSettings extends ChangeNotifier {
  /// 快捷指令的默认内容，可在设置页增删
  static const List<String> defaultQuickCommands = <String>[
    'AT',
    'AT+GMR',
    'AT+RESET',
  ];

  SerialViewMode _mode = SerialViewMode.normal;
  bool _showTimestamp = true;
  bool _showByteCount = true;
  bool _showDirection = true;
  bool _showHexView = false;
  bool _showQuickCommands = false;
  final List<String> _quickCommands =
      List<String>.of(defaultQuickCommands);

  SerialViewMode get mode => _mode;

  bool get isCustom => _mode == SerialViewMode.custom;

  bool get showTimestamp => _showTimestamp;

  bool get showByteCount => _showByteCount;

  /// 方向标签：普通模式固定显示，不提供开关
  bool get showDirection => isCustom ? _showDirection : true;

  /// 内容按 HEX 显示：只有自定义模式可用
  bool get showHexView => isCustom && _showHexView;

  /// 快捷指令栏：只有自定义模式可用
  bool get showQuickCommands => isCustom && _showQuickCommands;

  List<String> get quickCommands => List<String>.unmodifiable(_quickCommands);

  void setMode(SerialViewMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  void setShowTimestamp(bool value) {
    if (_showTimestamp == value) return;
    _showTimestamp = value;
    notifyListeners();
  }

  void setShowByteCount(bool value) {
    if (_showByteCount == value) return;
    _showByteCount = value;
    notifyListeners();
  }

  void setShowDirection(bool value) {
    if (_showDirection == value) return;
    _showDirection = value;
    notifyListeners();
  }

  void setShowHexView(bool value) {
    if (_showHexView == value) return;
    _showHexView = value;
    notifyListeners();
  }

  void setShowQuickCommands(bool value) {
    if (_showQuickCommands == value) return;
    _showQuickCommands = value;
    notifyListeners();
  }

  /// 添加快捷指令：去空白、重复的不加
  void addQuickCommand(String command) {
    final String value = command.trim();
    if (value.isEmpty || _quickCommands.contains(value)) return;
    _quickCommands.add(value);
    notifyListeners();
  }

  void removeQuickCommand(String command) {
    if (!_quickCommands.remove(command)) return;
    notifyListeners();
  }
}
