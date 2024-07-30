import 'package:demo_app/service/detection_result.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class ShowImage extends StatelessWidget {
  const ShowImage({super.key, required this.imagePath, this.detectionResult});

  final String imagePath;
  final DetectionResult? detectionResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Show Image'),
      ),
      body: Center(
        child: Image.file(File(imagePath)),
      ),
    );
  }
}
