import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// 姿态角（欧拉角），单位：度。
class OrientationAngles {
  const OrientationAngles({
    required this.roll,
    required this.pitch,
    required this.yaw,
  });

  final double roll; // 绕 X 轴：手机左右倾斜（横屏/竖屏翻转）
  final double pitch; // 绕 Y 轴：手机前后倾斜（低头/抬头）
  final double yaw; // 绕 Z 轴：手机水平朝向（东南西北）
}

/// 姿态估算服务。
///
/// 为什么不能只用陀螺仪？
/// 陀螺仪给出的是【角速度】，角度要靠积分累加。积分会把每次读数的微小偏置
/// 都放大成误差，几秒后角度就开始漂移，且无法自动纠正。
///
/// 解法：Mahony 互补滤波。
///   - 陀螺仪：负责“快”，短时间内的相对变化很准；
///   - 加速度计：提供重力方向，用来纠正 roll / pitch 的漂移；
///   - 磁力计：提供地磁方向，用来纠正 yaw 的漂移。
/// 三者融合，就得到稳定、不发散的三轴姿态角。
class OrientationService {
  final StreamController<OrientationAngles> _controller =
      StreamController.broadcast();

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  /// 对外事件流：每收到一帧陀螺仪数据，输出一次融合后的姿态角。
  Stream<OrientationAngles> get events => _controller.stream;

  // ---------- Mahony 滤波内部状态 ----------
  // 姿态用四元数 (q0,q1,q2,q3) 表示，可避免欧拉角的万向锁问题。
  double _q0 = 1, _q1 = 0, _q2 = 0, _q3 = 0;
  double _exInt = 0, _eyInt = 0, _ezInt = 0;
  DateTime? _lastTime;

  // 最近一帧的加速度计 / 磁力计读数（作为融合参考）
  double _ax = 0, _ay = 0, _az = 9.81;
  double _mx = 0, _my = 0, _mz = 0;
  bool _hasMag = false;

  static const double _kp = 2.0; // 比例增益：越大越快速追平参考，越小越平滑
  static const double _ki = 0.0; // 积分增益（这里用 0，避免磁力计噪声累积）

  void start() {
    _gyroSub ??= gyroscopeEventStream().listen(_onGyro);
    _accelSub ??= accelerometerEventStream().listen(_onAccel);
    _magSub ??= magnetometerEventStream().listen(_onMag);
  }

  void stop() {
    _gyroSub?.cancel();
    _gyroSub = null;
    _accelSub?.cancel();
    _accelSub = null;
    _magSub?.cancel();
    _magSub = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void _onGyro(GyroscopeEvent e) {
    // 计算两帧之间的时间差 dt，用于积分
    final now = DateTime.now();
    final dt = _lastTime == null
        ? 0.02
        : now.difference(_lastTime!).inMicroseconds / 1e6;
    _lastTime = now;
    // 真实设备采样率可能很低（实测约 5Hz，dt≈0.2s），阈值要放宽。
    // 只挡掉真正的长停顿（>1s），避免积分爆炸。
    if (dt <= 0 || dt > 1.0) return;

    _update(e.x, e.y, e.z, _ax, _ay, _az, _mx, _my, _mz, dt);
    _controller.add(_toAngles());
  }

  void _onAccel(AccelerometerEvent e) {
    _ax = e.x;
    _ay = e.y;
    _az = e.z;
  }

  void _onMag(MagnetometerEvent e) {
    _mx = e.x;
    _my = e.y;
    _mz = e.z;
    _hasMag = true;
  }

  /// Mahony 互补滤波单步更新。
  void _update(double gx, double gy, double gz, double ax, double ay, double az,
      double mx, double my, double mz, double dt) {
    double norm, hx, hy, bx, bz, vx, vy, vz, wx, wy, wz, ex, ey, ez;

    // 归一化加速度（消除量纲与大小影响，只保留方向）
    norm = math.sqrt(ax * ax + ay * ay + az * az);
    if (norm < 1e-9) return;
    ax /= norm;
    ay /= norm;
    az /= norm;

    if (_hasMag) {
      // 归一化磁力计
      norm = math.sqrt(mx * mx + my * my + mz * mz);
      if (norm > 1e-9) {
        mx /= norm;
        my /= norm;
        mz /= norm;
      }

      // 地磁场参考方向
      hx = 2 * mx * (0.5 - _q2 * _q2 - _q3 * _q3) +
          2 * my * (_q1 * _q2 - _q0 * _q3) +
          2 * mz * (_q1 * _q3 + _q0 * _q2);
      hy = 2 * mx * (_q1 * _q2 + _q0 * _q3) +
          2 * my * (0.5 - _q1 * _q1 - _q3 * _q3) +
          2 * mz * (_q2 * _q3 - _q0 * _q1);
      bx = math.sqrt(hx * hx + hy * hy);
      bz = 2 * mx * (_q1 * _q3 - _q0 * _q2) +
          2 * my * (_q2 * _q3 + _q0 * _q1) +
          2 * mz * (0.5 - _q1 * _q1 - _q2 * _q2);
    } else {
      bx = 0;
      bz = 0;
    }

    // 由当前四元数估计的重力方向 v
    vx = 2 * (_q1 * _q3 - _q0 * _q2);
    vy = 2 * (_q0 * _q1 + _q2 * _q3);
    vz = _q0 * _q0 - _q1 * _q1 - _q2 * _q2 + _q3 * _q3;

    // 估计的地磁场方向 w
    if (_hasMag) {
      wx = 2 * bx * (0.5 - _q2 * _q2 - _q3 * _q3) +
          2 * bz * (_q1 * _q3 - _q0 * _q2);
      wy = 2 * bx * (_q1 * _q2 - _q0 * _q3) +
          2 * bz * (_q0 * _q1 + _q2 * _q3);
      wz = 2 * bx * (_q0 * _q2 + _q1 * _q3) +
          2 * bz * (0.5 - _q1 * _q1 - _q2 * _q2);
    } else {
      wx = 0;
      wy = 0;
      wz = 0;
    }

    // 误差 = 测量方向 与 估计方向 的叉积（越小代表估计越接近真实）
    ex = (ay * vz - az * vy) + (my * wz - mz * wy);
    ey = (az * vx - ax * vz) + (mz * wx - mx * wz);
    ez = (ax * vy - ay * vx) + (mx * wy - my * wx);

    // 误差积分项
    _exInt += ex * _ki;
    _eyInt += ey * _ki;
    _ezInt += ez * _ki;

    // 用误差修正角速度（这是“把漂移拉回来”的关键）
    gx += _kp * ex + _exInt;
    gy += _kp * ey + _eyInt;
    gz += _kp * ez + _ezInt;

    // 四元数积分（一阶欧拉法）
    final dq = 0.5 * dt;
    _q0 += (-_q1 * gx - _q2 * gy - _q3 * gz) * dq;
    _q1 += (_q0 * gx + _q2 * gz - _q3 * gy) * dq;
    _q2 += (_q0 * gy - _q1 * gz + _q3 * gx) * dq;
    _q3 += (_q0 * gz + _q1 * gy - _q2 * gx) * dq;

    // 归一化四元数，保持单位长度
    norm = math.sqrt(_q0 * _q0 + _q1 * _q1 + _q2 * _q2 + _q3 * _q3);
    if (norm > 1e-12) {
      _q0 /= norm;
      _q1 /= norm;
      _q2 /= norm;
      _q3 /= norm;
    }
  }

  /// 四元数 -> 欧拉角（度）。
  OrientationAngles _toAngles() {
    final roll = math.atan2(2 * (_q0 * _q1 + _q2 * _q3),
        1 - 2 * (_q1 * _q1 + _q2 * _q2));
    final pitch = math.asin(
        math.max(-1, math.min(1, 2 * (_q0 * _q2 - _q3 * _q1))));
    final yaw = math.atan2(
        2 * (_q0 * _q3 + _q1 * _q2), 1 - 2 * (_q2 * _q2 + _q3 * _q3));
    const deg = 180.0 / math.pi;
    return OrientationAngles(
      roll: roll * deg,
      pitch: pitch * deg,
      yaw: yaw * deg,
    );
  }
}
