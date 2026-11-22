import 'package:flutter/material.dart';

/// 主题状态控制器。
///
/// 为什么单独抽出来：顶部栏按钮和设置页都要改主题，
/// 如果 ThemeMode 藏在某个页面的 State 里，另一处就拿不到它。
/// 做成 ChangeNotifier 后，谁都能读、谁都能改，由根节点统一重建。
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  /// 当前主题模式（交给 MaterialApp.themeMode）
  ThemeMode get mode => _mode;

  /// 当前是否暗色
  bool get isDark => _mode == ThemeMode.dark;

  /// 直接设置亮 / 暗（设置页开关用）
  void setDark(bool dark) {
    final ThemeMode next = dark ? ThemeMode.dark : ThemeMode.light;
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
  }

  /// 在亮 / 暗之间来回切换（顶部栏按钮用）
  void toggle() => setDark(!isDark);
}
