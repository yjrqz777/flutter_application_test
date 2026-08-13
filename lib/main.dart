import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 当前主题模式（初始为亮色）
  ThemeMode _themeMode = ThemeMode.light;

  // 切换主题：亮色 <-> 暗色 来回切换
  void _toggleThemeMode() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.light;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: HomePage(
        title: 'Flutter Demo Home Page',
        onToggleTheme: _toggleThemeMode,
      ),
      debugShowCheckedModeBanner: false, // 是否显示右上角 DEBUG 横幅
    );
  }
}
