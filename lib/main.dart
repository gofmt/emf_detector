import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'emf_detector_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.sensors.request();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '电磁探测器',
      theme: ThemeData(primarySwatch: Colors.blue, visualDensity: VisualDensity.adaptivePlatformDensity),
      home: const EmfDetectorScreen(),
    );
  }
}
