import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../app/theme_controller.dart';
import '../sensors/gyroscope_service.dart';
import '../sensors/orientation_service.dart';
import '../widgets/app_drawer.dart';

/// 主页面：负责计数器 + 陀螺仪数据的展示。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.title,
    required this.themeController,
  });

  final String title;

  /// 主题状态：顶部栏按钮切换它，「设置」页也改它
  final ThemeController themeController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 抽屉要用 ScaffoldState 打开，所以给 Scaffold 挂一个 key
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _counter = 0;

  // 陀螺仪订阅与显示值
  final GyroscopeService _gyroscope = GyroscopeService();
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _gx = 0;
  double _gy = 0;
  double _gz = 0;
  bool _gyroActive = false;

  // 姿态角（由 Mahony 互补滤波算出）
  final OrientationService _orientation = OrientationService();
  StreamSubscription<OrientationAngles>? _orientSub;
  OrientationAngles? _angles;

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

    _orientation.start();
    _orientSub = _orientation.events.listen((angles) {
      if (!mounted) return;
      setState(() => _angles = angles);
    });
  }

  @override
  void dispose() {
    _gyroSub?.cancel(); // 先取消界面订阅
    _gyroscope.dispose(); // 再释放服务资源
    _orientSub?.cancel();
    _orientation.dispose();
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

  /// 左上角菜单按钮：从侧面滑出抽屉
  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(themeController: widget.themeController),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: '打开菜单',
          onPressed: _openDrawer,
        ),
        actions: [
          IconButton(
            // 切换主题：当前主题决定图标显示成“太阳”还是“月亮”
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: '切换主题',
            onPressed: widget.themeController.toggle,
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
            // 姿态角展示（Mahony 互补滤波融合陀螺仪/加速度计/磁力计）
            Text(
              _angles != null ? '姿态角 roll / pitch / yaw' : '正在校准姿态角…',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              _angles == null
                  ? '请保持手机静止几秒以初始化'
                  : 'roll  ${_angles!.roll.toStringAsFixed(1)}°\n'
                      'pitch ${_angles!.pitch.toStringAsFixed(1)}°\n'
                      'yaw   ${_angles!.yaw.toStringAsFixed(1)}°',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            // 磁力计状态：yaw 有没有绝对参考，直接决定它会不会漂移
            Text(
              _orientation.hasMagnetometer
                  ? '磁力计：正常（yaw 有参考）'
                  : '磁力计：无数据（yaw 会漂移）',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            // 陀螺仪原始数据展示（对比用）
            Text(
              _gyroActive ? '陀螺仪角速度 x/y/z (rad/s)' : '等待陀螺仪数据…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'x: ${_gx.toStringAsFixed(2)}\n'
              'y: ${_gy.toStringAsFixed(2)}\n'
              'z: ${_gz.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
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
