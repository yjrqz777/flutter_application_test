import 'package:flutter/material.dart';

// 全局主题：所有样式集中在这里管理，改一处全 App 生效。
// 主题分为 亮色(light) 和 暗色(dark) 两套。
class AppTheme {
  AppTheme._();

  /// 种子色：决定整个配色方案的基调（当前为绿色）。
  static const Color _seedColor = Color.fromARGB(255, 33, 156, 105);

  /// 亮色主题
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
        textTheme: _textTheme,
        appBarTheme: const AppBarTheme(
          toolbarHeight: 80, // 顶部栏高度
          // 圆角造型（上下各 20）
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
              bottom: Radius.circular(20),
            ),
          ),
        ),
      );

  /// 暗色主题
  static ThemeData get dark => ThemeData.dark();

  /// 统一的文字样式表
  static const TextTheme _textTheme = TextTheme(
    // “你好” 用的大标题样式
    titleLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.bold,
      color: Colors.blue,
      fontFamily: 'SimSun',
    ),
    // 计数器数字用的大号标题样式
    headlineMedium: TextStyle(
      fontSize: 80,
      fontWeight: FontWeight.bold,
      color: Colors.red,
      fontFamily: 'SimSun',
    ),
  );
}
