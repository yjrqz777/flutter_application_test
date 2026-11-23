# 多功能调试工具

面向硬件调试的 Flutter 工具：查看陀螺仪与姿态角，用经典蓝牙或 BLE（Bluetooth Low Energy，低功耗蓝牙）串口和板子收发数据。

## 功能

- 陀螺仪角速度实时显示，Mahony 互补滤波融合出姿态角（roll / pitch / yaw）
- 经典蓝牙（SPP，Serial Port Profile，串口协议）串口收发调试
- BLE 串口（GATT，Generic Attribute Profile，通用属性协议透传）收发调试
- 经典蓝牙和 BLE 合并在同一个「蓝牙调试」页，顶部用分段按钮切换模式
- 经典蓝牙列表里标出已配对设备
- 普通 / 自定义两种串口调试页，时间戳、字节计数、方向标签、HEX 视图、快捷指令栏可开关
- 亮色 / 暗色主题切换

## 页面

| 页面 | 说明 |
| --- | --- |
| 入口页 | test、蓝牙调试、关于三个圆形入口，页面从按钮圆心展开 |
| test | 计数器、陀螺仪数据与姿态角 |
| 蓝牙调试 | 模式切换、扫描、连接、串口控制台，右上角进串口页设置 |
| 设置 | 主题切换 |
| 关于 | 应用信息与功能列表 |

### 蓝牙调试页

- 顶部分段按钮在「经典蓝牙」和「BLE 蓝牙」之间切换，扫描、连接、断开的都是当前模式。
- 经典蓝牙模式一进页面就加载系统里已配对的设备，列表副标题显示「已配对 / 配对中 / 未配对」。
- 状态文字和扫描按钮同一行：文字在左，按钮在右。
- 正在扫描时切换模式会先停止扫描；已连接或正在连接时切换会提示先断开。

## 目录结构

```text
lib/
  app/         应用信息、主题控制、页面转场与圆形展开动画
  bluetooth/   串口会话基类、经典蓝牙与 BLE 服务、串口消息和显示设置
  pages/       入口、test、设置、关于、蓝牙调试和串口设置页
  previews/    Widget Preview 预览入口
  sensors/     传感器数据与姿态解算
  widgets/     控制台、设备列表项、操作条、空状态等通用组件
  main.dart    程序入口
  theme.dart   全局主题
```

## 运行

需要 Flutter SDK（Dart 3.12 及以上）。Android 手机和 Windows / Linux 桌面都能跑，蓝牙功能要求设备本身有对应硬件。

```bash
flutter pub get
```

```bash
flutter run
```

### 手机无线调试

1. 手机和电脑连同一个 Wi-Fi，打开「开发者选项 → 无线调试」。
2. 点「使用配对码配对设备」，记下屏幕上的 IP:端口 和六位配对码。
3. 电脑上配对，按提示输入配对码：

```bash
adb pair 192.168.1.5:37123
```

4. 回到无线调试页，用「IP 地址和端口」连接：

```bash
adb connect 192.168.1.5:41234
```

5. 直接跑到手机上：

```bash
flutter run -d 192.168.1.5:41234
```

## 依赖说明

- flutter_classic_bluetooth：经典蓝牙（SPP）
- flutter_blue_plus：BLE（GATT）
- sensors_plus：陀螺仪、加速度计

注意：flutter_blue_plus 对营利性使用要求购买商业授权。代码里显式声明了 `License.nonprofit`，商用前请改成 `License.commercial` 并购买授权。

## Widget 预览

`lib/previews/app_previews.dart` 里给每个页面写了 `@Preview`，可以在编辑器的 Widget Preview 面板直接看页面，不用启动模拟器。
