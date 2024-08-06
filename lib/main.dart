// import 'dart:ui';

// import 'package:demo_app/detector.dart';
// import 'package:flutter/material.dart';
// import 'package:demo_app/utils/themes/theme.dart';

// main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   DartPluginRegistrant.ensureInitialized();
//   runApp(
//     MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: CustomTheme.lightTheme,
//       darkTheme: CustomTheme.darkTheme,
//       home: const Detector(),
//     ),
//   );
// }

import 'package:camera/camera.dart';
import 'package:demo_app/screens/camera_app.dart';

import 'package:demo_app/utils/themes/theme.dart';
import 'package:flutter/material.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();

  return runApp(MainApp(
    cameras: cameras,
  ));
}

class MainApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MainApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CustomTheme.lightTheme,
      darkTheme: CustomTheme.darkTheme,
      home: CameraApp(cameras: cameras),
    );
  }
}
