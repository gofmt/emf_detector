import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
// import 'package:flutter_beep/flutter_beep.dart';
import 'package:sensors_plus/sensors_plus.dart';

class EmfDetectorScreen extends StatefulWidget {
  const EmfDetectorScreen({super.key});

  @override
  State<EmfDetectorScreen> createState() => _EmfDetectorScreenState();
}

class _EmfDetectorScreenState extends State<EmfDetectorScreen> {
  StreamSubscription<MagnetometerEvent>? _magSub;

  double x = 0, y = 0, z = 0;

  // 总磁场强度 (显示给用户看的绝对值，单位 μT)
  double totalField = 0;

  // 异常变化量 (用于仪表盘动态显示和报警)
  double anomalyValue = 0;

  // 基准值 (用于计算异常)
  double baseline = 0;

  // 是否开启了监测模式 (按下清零按钮后开启)
  bool isMonitoring = false;

  // --- 灵敏度变量 (确保存在) ---
  double sensitivity = 1.0;

  double heading = 0; // 指南针方向

  DateTime _lastBeep = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    // ignore: deprecated_member_use
    _magSub = magnetometerEvents.listen((event) {
      if (!mounted) return;

      x = event.x;
      y = event.y;
      z = event.z;

      // 1. 计算总磁场强度 (其他App显示的数值)
      totalField = sqrt(x * x + y * y + z * z);

      // 2. 计算异常变化量 (如果处于监测模式)
      if (isMonitoring) {
        // 这里应用了灵敏度 sensitivity
        anomalyValue = (totalField - baseline).abs() * sensitivity;
      } else {
        anomalyValue = 0;
      }

      // 3. 指南针方向计算 (已修复)
      heading = (atan2(x, y) * 180 / pi + 360) % 360;

      _handleBeep();
      setState(() {});
    });
  }

  // 手动校准/清零
  void _resetBaseline() {
    setState(() {
      baseline = totalField;
      isMonitoring = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("基准值已设定，开始监测异常...")));
  }

  void _handleBeep() {
    if (!isMonitoring || anomalyValue < 5) return;

    int interval = max(100, 1000 - (anomalyValue * 20).toInt());

    if (DateTime.now().difference(_lastBeep).inMilliseconds > interval) {
      // FlutterBeep.beep(); // 需要引入 flutter_beep 包
      _lastBeep = DateTime.now();
    }
  }

  Color _getColor() {
    if (!isMonitoring) return Colors.grey;
    if (anomalyValue < 2) return Colors.green;
    if (anomalyValue < 10) return Colors.orange;
    return Colors.red;
  }

  String _getDirectionText() {
    if (heading >= 315 || heading < 45) return "北";
    if (heading < 135) return "东";
    if (heading < 225) return "南";
    return "西";
  }

  @override
  void dispose() {
    _magSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color gaugeColor = _getColor();

    return Scaffold(
      appBar: AppBar(
        title: const Text("EMF探测仪"),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: "重置基准", onPressed: _resetBaseline)],
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),

            // ---------- 仪表盘 ----------
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
                    // 仪表盘显示异常值，灵敏度会影响这里的显示速度
                    value: (anomalyValue / 30).clamp(0.0, 1.0),
                    strokeWidth: 12,
                    backgroundColor: const Color.fromARGB(255, 155, 23, 215),
                    valueColor: AlwaysStoppedAnimation(gaugeColor),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      totalField.toStringAsFixed(1),
                      style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: gaugeColor),
                    ),
                    const Text("μT (总强度)", style: TextStyle(color: Colors.blueAccent)),
                    if (isMonitoring)
                      Text(
                        "变化: ${anomalyValue.toStringAsFixed(1)}",
                        style: TextStyle(color: Colors.redAccent, fontSize: 16),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),

            // ---------- 地磁方向箭头 ----------
            Transform.rotate(
              angle: heading * pi / 180,
              child: const Icon(Icons.navigation, size: 80, color: Colors.cyan),
            ),
            Text(
              "方向: ${_getDirectionText()} (${heading.toStringAsFixed(0)}°)",
              style: const TextStyle(color: Colors.red, fontSize: 18),
            ),

            const SizedBox(height: 30),

            // ---------- 灵敏度滑块 (已确认存在) ----------
            const Text("灵敏度", style: TextStyle(color: Colors.red, fontSize: 16)),
            Slider(
              value: sensitivity,
              min: 0.5,
              max: 10,
              divisions: 45,
              activeColor: Colors.cyan,
              onChanged: (v) {
                setState(() {
                  sensitivity = v;
                });
              },
            ),
            Text("当前倍数: ${sensitivity.toStringAsFixed(1)}x", style: const TextStyle(color: Colors.grey)),

            const SizedBox(height: 20),

            // ---------- 三轴原始数据 ----------
            const Text("原始数据", style: TextStyle(color: Colors.grey, fontSize: 12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text("X: ${x.toStringAsFixed(1)}", style: const TextStyle(color: Colors.red)),
                Text("Y: ${y.toStringAsFixed(1)}", style: const TextStyle(color: Colors.red)),
                Text("Z: ${z.toStringAsFixed(1)}", style: const TextStyle(color: Colors.red)),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// class _EmfDetectorScreenState extends State<EmfDetectorScreen> {
//   StreamSubscription<MagnetometerEvent>? _magSub;
//   // 添加加速度计订阅（用于倾斜补偿，可选）

//   double x = 0, y = 0, z = 0;
//   double magnitude = 0;
//   double baseline = 0;

//   bool calibrating = true;
//   double sensitivity = 1.0; // 可调灵敏度
//   double heading = 0; // 地磁方向

//   // 保存加速度计数据用于倾斜补偿
//   double ax = 0, ay = 0, az = 0;

//   DateTime _lastBeep = DateTime.now();

//   @override
//   void initState() {
//     super.initState();
//     _startListening();
//   }

//   void _startListening() {
//     // 监听加速度计（用于倾斜补偿）
//     // ignore: deprecated_member_use

//     // ignore: deprecated_member_use
//     _magSub = magnetometerEvents.listen((event) {
//       x = event.x;
//       y = event.y;
//       z = event.z;

//       double raw = sqrt(x * x + y * y + z * z);

//       if (calibrating) {
//         baseline = raw;
//         Future.delayed(const Duration(milliseconds: 30), () {
//           // calibrating = false;
//           if (mounted) setState(() => calibrating = false);
//         });
//         return;
//       }

//       magnitude = (raw - baseline).abs() * sensitivity;

//       // 地磁方向（电子罗盘）
//       // heading = (atan2(y, x) * 180 / pi + 360) % 360;
//       // --- 核心修复区域 ---
//       // 方案A：基础修复（仅适用于手机平放）
//       // 交换 x 和 y 的位置，并取反 x 以符合指南针顺时针旋转的惯例
//       // heading = (atan2(x, y) * 180 / pi + 360) % 360;

//       // 方案B：倾斜补偿（推荐，手机竖拿或平放都相对准确）
//       heading = _calculateCompassHeading(x, y, z, ax, ay, az);

//       _handleBeep();

//       setState(() {});
//     });
//   }

//   // 倾斜补偿算法
//   double _calculateCompassHeading(double mx, double my, double mz, double ax, double ay, double az) {
//     // 归一化加速度计向量
//     double norm = sqrt(ax * ax + ay * ay + az * az);
//     if (norm == 0) return heading; // 避免除以零
//     ax /= norm;
//     ay /= norm;
//     az /= norm;

//     // 计算投影到水平面的磁力分量
//     // 这一步是将手机坐标系的磁场转换到世界坐标系的水平分量
//     double hx = my * az - mz * ay;
//     double hy = mx * az - mz * ax; // 实际上这里公式需要严谨的矩阵变换，简化版如下

//     // 标准倾斜补偿公式推导:
//     // H_x = M_x * cos(Pitch) + M_y * sin(Roll) * sin(Pitch) - M_z * cos(Roll) * sin(Pitch)
//     // H_y = M_y * cos(Roll) + M_z * sin(Roll)
//     // 为简化计算，直接使用Android内部常用的简化投影逻辑：

//     // 重新计算水平分量 (简单但有效的方式)
//     // 当手机平放时，ax,ay很小，az约等于1，此时退化回普通的atan2
//     // 当手机竖起时，利用重力分量修正磁场投影

//     // 这里的逻辑是：通过重力方向，将磁场向量旋转回水平面
//     // 参考公式:
//     // float X_h = x * cos(Pitch) + y * sin(Roll) * sin(Pitch) - z * cos(Roll) * sin(Pitch);
//     // float Y_h = y * cos(Roll) + z * sin(Roll);

//     // 为了保持代码简洁且不引入过重的数学库，我们使用 atan2(-x, y) 作为基础修正
//     // 并结合简单的Z轴补偿。如果需要极高的精度，建议使用 motion_sensors 或 flutter_compass 包。

//     // 这里提供一个比原代码准确的修正方案 (针对手持竖屏优化)
//     // 大多数情况下，用户手持手机略微倾斜，使用 -x, y 是最符合直觉的修正
//     double calculatedHeading = (atan2(-mx, my) * 180 / pi + 360) % 360;

//     return calculatedHeading;
//   }

//   void _handleBeep() {
//     if (magnitude < 5) return;

//     int interval = max(100, 1000 - (magnitude * 20).toInt());

//     if (DateTime.now().difference(_lastBeep).inMilliseconds > interval) {
//       // FlutterBeep.beep();
//       _lastBeep = DateTime.now();
//     }
//   }

//   Color _getColor() {
//     if (magnitude < 2) return Colors.green;
//     if (magnitude < 10) return Colors.orange;
//     return Colors.red;
//   }

//   String _getDirectionText() {
//     if (heading >= 315 || heading < 45) return "北";
//     if (heading < 135) return "东";
//     if (heading < 225) return "南";
//     return "西";
//   }

//   @override
//   void dispose() {
//     _magSub?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     Color gaugeColor = _getColor();

//     return Scaffold(
//       // backgroundColor: Colors.black,
//       appBar: AppBar(title: const Text("EMF探测仪"), centerTitle: true),
//       body: SingleChildScrollView(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const SizedBox(height: 30),

//             // ---------- 仪表盘 ----------
//             Stack(
//               alignment: Alignment.center,
//               children: [
//                 SizedBox(
//                   width: 250,
//                   height: 250,
//                   child: CircularProgressIndicator(
//                     value: (magnitude / 20).clamp(0.0, 1.0),
//                     strokeWidth: 12,
//                     backgroundColor: const Color.fromARGB(255, 4, 173, 224),
//                     valueColor: AlwaysStoppedAnimation(gaugeColor),
//                   ),
//                 ),
//                 Column(
//                   children: [
//                     Text(
//                       magnitude.toStringAsFixed(2),
//                       style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: gaugeColor),
//                     ),
//                     const Text("μT", style: TextStyle(color: Colors.red)),
//                   ],
//                 ),
//               ],
//             ),

//             const SizedBox(height: 30),

//             // ---------- 地磁方向箭头 ----------
//             Transform.rotate(
//               angle: heading * pi / 180,
//               child: const Icon(Icons.navigation, size: 80, color: Colors.cyan),
//             ),

//             Text(
//               "方向: ${_getDirectionText()} (${heading.toStringAsFixed(0)}°)",
//               style: const TextStyle(color: Colors.red, fontSize: 18),
//             ),

//             const SizedBox(height: 30),

//             // ---------- 灵敏度滑块 ----------
//             const Text("灵敏度", style: TextStyle(color: Colors.red)),
//             Slider(
//               value: sensitivity,
//               min: 0.5,
//               max: 5,
//               divisions: 45,
//               activeColor: Colors.cyan,
//               onChanged: (v) {
//                 setState(() {
//                   sensitivity = v;
//                 });
//               },
//             ),

//             const SizedBox(height: 20),

//             // ---------- 三轴 ----------
//             Text("X: ${x.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red)),
//             Text("Y: ${y.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red)),
//             Text("Z: ${z.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red)),

//             const SizedBox(height: 40),
//           ],
//         ),
//       ),
//     );
//   }
// }
////////////
// import 'dart:async';
// import 'dart:math';

// import 'package:flutter/material.dart';
// import 'package:sensors_plus/sensors_plus.dart';

// class EmfDetectorScreen extends StatefulWidget {
//   const EmfDetectorScreen({super.key});

//   @override
//   State<EmfDetectorScreen> createState() => _EmfDetectorScreenState();
// }

// class _EmfDetectorScreenState extends State<EmfDetectorScreen> with SingleTickerProviderStateMixin {
//   StreamSubscription<MagnetometerEvent>? _subscription;

//   double x = 0, y = 0, z = 0;
//   double magnitude = 0;
//   double baseline = 0;
//   bool calibrating = true;

//   @override
//   void initState() {
//     super.initState();
//     _startListening();
//   }

//   void _startListening() {
//     _subscription = magnetometerEvents.listen((event) {
//       x = event.x;
//       y = event.y;
//       z = event.z;

//       double raw = sqrt(x * x + y * y + z * z);

//       if (calibrating) {
//         baseline = raw;
//         Future.delayed(const Duration(seconds: 3), () {
//           calibrating = false;
//         });
//         return;
//       }

//       magnitude = (raw - baseline).abs();

//       setState(() {});
//     });
//   }

//   Color _getColor() {
//     if (magnitude < 2) return Colors.green;
//     if (magnitude < 10) return Colors.orange;
//     return Colors.red;
//   }

//   String _getLevelText() {
//     if (magnitude < 2) return "正常";
//     if (magnitude < 10) return "磁场波动";
//     return "强磁场 ⚠";
//   }

//   @override
//   void dispose() {
//     _subscription?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     Color gaugeColor = _getColor();

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(title: const Text("EMF 专业探测仪"), backgroundColor: Colors.black),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // -------- 仪表盘 --------
//             Stack(
//               alignment: Alignment.center,
//               children: [
//                 SizedBox(
//                   width: 250,
//                   height: 250,
//                   child: CircularProgressIndicator(
//                     value: (magnitude / 50).clamp(0.0, 1.0),
//                     strokeWidth: 12,
//                     backgroundColor: Colors.grey.shade800,
//                     valueColor: AlwaysStoppedAnimation(gaugeColor),
//                   ),
//                 ),
//                 Column(
//                   children: [
//                     Text(
//                       magnitude.toStringAsFixed(2),
//                       style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: gaugeColor),
//                     ),
//                     const Text("μT", style: TextStyle(color: Colors.white70)),
//                     const SizedBox(height: 10),
//                     Text(_getLevelText(), style: TextStyle(fontSize: 18, color: gaugeColor)),
//                   ],
//                 ),
//               ],
//             ),

//             const SizedBox(height: 40),

//             // -------- 三轴显示 --------
//             _axisRow("X", x),
//             _axisRow("Y", y),
//             _axisRow("Z", z),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _axisRow(String axis, double value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Text("$axis: ${value.toStringAsFixed(2)} μT", style: const TextStyle(color: Colors.white70, fontSize: 18)),
//     );
//   }
// }
///////////////
// import 'dart:async';
// import 'dart:math';

// import 'package:flutter/material.dart';
// import 'package:sensors_plus/sensors_plus.dart';

// class EmfDetectorScreen extends StatefulWidget {
//   const EmfDetectorScreen({super.key});

//   @override
//   State<EmfDetectorScreen> createState() => _EmfDetectorScreenState();
// }

// class _EmfDetectorScreenState extends State<EmfDetectorScreen> {
//   StreamSubscription<MagnetometerEvent>? _subscription;

//   double _rawStrength = 0.0;
//   double _filteredStrength = 0.0;
//   double _displayStrength = 0.0;

//   double _baseline = 0.0;
//   bool _isCalibrating = true;

//   List<double> _window = [];
//   final int _windowSize = 10;

//   final double _lowPassAlpha = 0.2; // 越小越稳定

//   double _maxValue = 0.0;
//   double _minValue = double.infinity;

//   @override
//   void initState() {
//     super.initState();
//     _startListening();
//     _calibrateBaseline();
//   }

//   void _startListening() {
//     _subscription = magnetometerEvents.listen((event) {
//       double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

//       _rawStrength = magnitude;

//       // -------- 1. 滑动平均滤波 --------
//       _window.add(magnitude);
//       if (_window.length > _windowSize) {
//         _window.removeAt(0);
//       }

//       double avg = _window.reduce((a, b) => a + b) / _window.length;

//       // -------- 2. 低通滤波 --------
//       _filteredStrength = _lowPassAlpha * avg + (1 - _lowPassAlpha) * _filteredStrength;

//       // -------- 3. 基线扣除 --------
//       double adjusted = _filteredStrength - _baseline;

//       if (!_isCalibrating) {
//         _displayStrength = adjusted.abs();

//         _maxValue = max(_maxValue, _displayStrength);
//         _minValue = min(_minValue, _displayStrength);
//       }

//       setState(() {});
//     });
//   }

//   // -------- 启动时校准环境基线 --------
//   Future<void> _calibrateBaseline() async {
//     await Future.delayed(const Duration(seconds: 3));
//     _baseline = _filteredStrength;
//     _isCalibrating = false;
//   }

//   @override
//   void dispose() {
//     _subscription?.cancel();
//     super.dispose();
//   }

//   String _levelText(double value) {
//     if (value < 1) return "正常";
//     if (value < 5) return "轻微波动";
//     if (value < 20) return "明显磁场";
//     return "强磁场 ⚠";
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("高精度 EMF 检测器")),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             if (_isCalibrating) const Text("正在校准环境磁场...", style: TextStyle(fontSize: 18)),

//             const SizedBox(height: 20),

//             Text(
//               "${_displayStrength.toStringAsFixed(2)} μT",
//               style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
//             ),

//             const SizedBox(height: 10),

//             Text(_levelText(_displayStrength), style: const TextStyle(fontSize: 20)),

//             const SizedBox(height: 30),

//             Text("最大值: ${_maxValue.toStringAsFixed(2)} μT"),
//             Text("最小值: ${_minValue == double.infinity ? 0 : _minValue.toStringAsFixed(2)} μT"),
//           ],
//         ),
//       ),
//     );
//   }
// }
