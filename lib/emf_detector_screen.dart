import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart'; // 确保已引入
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmfDetectorScreen extends StatefulWidget {
  const EmfDetectorScreen({Key? key}) : super(key: key);

  @override
  State<EmfDetectorScreen> createState() => _EmfDetectorScreenState();
}

class _EmfDetectorScreenState extends State<EmfDetectorScreen> {
  StreamSubscription<MagnetometerEvent>? _magSub;

  double x = 0, y = 0, z = 0;
  double totalField = 0;
  double anomalyValue = 0;
  double baseline = 0;
  bool isMonitoring = false;
  double sensitivity = 1.0;
  double heading = 0;
  DateTime _lastBeep = DateTime.now();

  // ============================
  // 📝 新增：记录功能所需成员变量
  // ============================
  static const String _recordKey = 'emf_records';
  static const Duration _recordInterval = Duration(minutes: 6); // 6分钟记录一次
  final List<Map<String, dynamic>> _currentRecordBuffer = [];
  DateTime? _lastRecordTime;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _initRecords();
    _startListening();
  }

  // 🔹 异步初始化 SharedPreferences & 加载历史记录（避免 initState 阻塞）
  Future<void> _initRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_recordKey) ?? '[]';
      final List<dynamic> jsonList = json.decode(jsonString);
      _records = List<Map<String, dynamic>>.from(jsonList);

      // 初始化 _lastRecordTime：设为当前时间 - 15 分钟，以便首次立即触发
      _lastRecordTime = DateTime.now().subtract(_recordInterval);
    } catch (e) {
      print('❌ 初始化记录失败: $e');
      _lastRecordTime = DateTime.now().subtract(_recordInterval);
    }
  }

  void _startListening() {
    // ignore: deprecated_member_use
    _magSub = magnetometerEvents.listen((event) {
      if (!mounted) return;

      x = event.x;
      y = event.y;
      z = event.z;

      // 1. 总磁场强度
      totalField = sqrt(x * x + y * y + z * z);

      // 2. 异常值计算
      if (isMonitoring) {
        anomalyValue = (totalField - baseline).abs() * sensitivity;
      } else {
        anomalyValue = 0;
      }

      // 3. 指南针方向
      heading = (atan2(x, y) * 180 / pi + 360) % 360;

      // ✅ 【新增】监测模式下缓存数据
      if (isMonitoring) {
        _currentRecordBuffer.add({'timestamp': DateTime.now().toIso8601String(), 'anomalyValue': anomalyValue});
      }

      // ✅ 【新增】检查是否到 6分钟需保存记录
      if (_lastRecordTime != null &&
          DateTime.now().difference(_lastRecordTime!).inMinutes >= _recordInterval.inMinutes) {
        _saveCurrentRecordBuffer();
        _lastRecordTime = DateTime.now(); // 更新起始时间点
      }

      _handleBeep();
      setState(() {});
    });
  }

  // ✅ 保存当前 buffer（聚合为一条记录）
  Future<void> _saveCurrentRecordBuffer() async {
    if (_currentRecordBuffer.isEmpty) {
      print('⚠ 缓冲区为空，跳过记录');
      return;
    }

    final values = _currentRecordBuffer.map((e) => e['anomalyValue'] as double).toList();
    final maxVal = values.fold<double>(0, (prev, curr) => curr > prev ? curr : prev);
    final minVal = values.fold<double>(double.infinity, (prev, curr) => curr < prev ? curr : prev);
    final avgVal = values.isNotEmpty ? values.reduce((a, b) => a + b) / values.length : 0;

    final record = {
      'startTime':
          _lastRecordTime?.toIso8601String().substring(0, 21) ?? DateTime.now().toIso8601String().substring(0, 21),
      'endTime': DateTime.now().toIso8601String().substring(0, 21),
      'max': double.parse(maxVal.toStringAsFixed(2)),
      'min': double.parse(minVal.toStringAsFixed(2)),
      'avg': double.parse(avgVal.toStringAsFixed(2)),
      'count': values.length,
    };

    _records.add(record);

    // 保存到 SharedPreferences（限制最多 600 条避免无限增长）
    final prefs = await SharedPreferences.getInstance();
    final listToSave = _records.length > 600
        ? _records.sublist(_records.length - 600) // 只保留最新 600 条
        : _records;
    await prefs.setString(_recordKey, json.encode(listToSave));

    // 清空缓冲区
    _currentRecordBuffer.clear();
    print('✅ 记录已保存: $record');
  }

  // 手动校准/清零
  void _resetBaseline() {
    setState(() {
      baseline = totalField;
      isMonitoring = true;
      // 可选：重置 lastRecordTime，避免新 baseline 影响旧记录逻辑
      _lastRecordTime ??= DateTime.now();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("基准值已设定为 ${baseline.toStringAsFixed(1)} μT，开始监测异常...")));
  }

  void _handleBeep() {
    if (!isMonitoring || anomalyValue < 5) return;

    // 动态调节蜂鸣间隔（值越大越快）
    int interval = max(100, 1000 - (anomalyValue * 20).toInt());
    if (DateTime.now().difference(_lastBeep).inMilliseconds > interval) {
      // 如需实际蜂鸣：FlutterBeep.beep();
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
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: "重置基准", onPressed: _resetBaseline),
          IconButton(icon: const Icon(Icons.storage), tooltip: "查看记录", onPressed: () => _showRecordsDialog()),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // ========== 仪表盘 ==========
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
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

            const SizedBox(height: 20),

            // ========== 地磁方向 ==========
            Transform.rotate(
              angle: heading * pi / 180,
              child: const Icon(Icons.navigation, size: 80, color: Colors.cyan),
            ),
            Text(
              "方向: ${_getDirectionText()} (${heading.toStringAsFixed(0)}°)",
              style: const TextStyle(color: Colors.red, fontSize: 18),
            ),

            const SizedBox(height: 30),

            // ========== 灵敏度滑块 ==========
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

            // ========== 三轴原始数据 ==========
            const Text("原始数据", style: TextStyle(color: Colors.grey, fontSize: 12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text("X: ${x.toStringAsFixed(1)}", style: const TextStyle(color: Colors.red)),
                Text("Y: ${y.toStringAsFixed(1)}", style: const TextStyle(color: Colors.red)),
                Text("Z: ${z.toStringAsFixed(1)}", style: const TextStyle(color: Colors.red)),
              ],
            ),

            // ========== 最近一条记录摘要 ==========
            if (_records.isNotEmpty) ...[
              const SizedBox(height: 30),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                elevation: 4,
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.blue),
                  title: Text("📊 最近记录", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    "时间: ${_records.last['endTime']} | "
                    "最大: ${_records.last['max']} μT | "
                    "最小: ${_records.last['min']} μT | "
                    "平均: ${_records.last['avg']} μT",
                  ),
                  isThreeLine: true,
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 🔹 弹窗显示完整记录历史（新增）
  Future<void> _showRecordsDialog() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("暂无记录，请先启用监测模式并等待首次记录...")));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("📋 EMF 记录历史"),
        content: SingleChildScrollView(
          child: ListBody(
            children: _records.reversed.take(5).map((r) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  "📅 ${r['endTime']}\n"
                  "📈 最大: ${r['max']} | 最小: ${r['min']} | 平均: ${r['avg']} μT\n"
                  "📊 点数: ${r['count']}",
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("关闭")),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_recordKey);
              setState(() {
                _records.clear();
                _currentRecordBuffer.clear();
              });
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("所有记录已清空")));
              // ignore: use_build_context_synchronously
              Navigator.pop(context);
            },
            child: const Text("清空记录"),
          ),
        ],
      ),
    );
  }
}
