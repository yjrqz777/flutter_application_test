import 'package:flutter/material.dart';

import 'app/app_info.dart';
import 'app/theme_controller.dart';
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
  // 主题状态统一放在这里：顶部栏按钮和「设置」页都改同一个对象
  final ThemeController _themeController = ThemeController();

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeController,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          title: AppInfo.appName,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeController.mode,
          home: HomePage(themeController: _themeController),
          debugShowCheckedModeBanner: false, // 是否显示右上角 DEBUG 横幅
        );
      },
    );
  }
}
