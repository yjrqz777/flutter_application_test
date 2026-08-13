import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../sensors/gyroscope_service.dart';

/// 主页面：负责计数器 + 陀螺仪数据的展示。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.title,
    required this.onToggleTheme,
  });

  final String title;
  final VoidCallback onToggleTheme;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;

  // 陀螺仪订阅与显示值
  final GyroscopeService _gyroscope = GyroscopeService();
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _gx = 0;
  double _gy = 0;
  double _gz = 0;
  bool _gyroActive = false;

  @override
  void initState() {
    super.initState();
    _gyroscope.start();
    _gyroSub = _gyroscope.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _gx = event.x;
        _gy = event.y;
        _gz = event.z;
        _gyroActive = true;
      });
    });
  }

  @override
  void dispose() {
    _gyroSub?.cancel(); // 先取消界面订阅
    _gyroscope.dispose(); // 再释放服务资源
    super.dispose();
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _cleanCounter() {
    setState(() {
      _counter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            // 切换主题：当前主题决定图标显示成“太阳”还是“月亮”
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_sharp),
            onPressed: _cleanCounter,
          ),
        ],
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Text(
              '你好',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            // 陀螺仪数据展示
            Text(
              _gyroActive ? '陀螺仪 x/y/z' : '等待陀螺仪数据…',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'x: ${_gx.toStringAsFixed(2)}\n'
              'y: ${_gy.toStringAsFixed(2)}\n'
              'z: ${_gz.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
