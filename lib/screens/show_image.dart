import 'package:demo_app/services/models/lpr_result.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class ShowImage extends StatelessWidget {
  const ShowImage({super.key, required this.imagePath, this.detectionResult});

  final String imagePath;
  final LPRResult? detectionResult;

  @override
  Widget build(BuildContext context) {
    Image image = Image.file(File(imagePath));
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Show Image'),
      ),
      body: Center(
        child: Stack(
          children: [image, ...displayBoxesAroundPlates(size, image)],
        ),
      ),
    );
  }

  List<Widget> displayBoxesAroundPlates(Size size, Image image) {
    if (detectionResult == null) {
      return [];
    }
    debugPrint("recognition saved: ${detectionResult}");
    if (detectionResult!.normalizedBoxesXyxy.isEmpty) {
      return [];
    }

    // double factorX = screen.width / (image?.height ?? 1);
    // double factorY = screen.height / (image?.width ?? 1);
    double factorY = image.width ?? 1;
    double factorX = image.height ?? 1;

    Color borderColor = const Color(0xFF2C3E50); // Dark blue-gray
    Color labelBackgroundColor = const Color(0xFF34495E); // Lighter blue-gray
    Color labelTextColor = Colors.white;
    int idx = 0;

    return detectionResult!.normalizedBoxesXyxy.map((result) {
      String plate_number = detectionResult!.plateNumbers[idx];
      double boxWidth = (result[3] - result[1]) * factorX;
      double boxHeight = (result[2] - result[0]) * factorY;
      bool isBoxTooSmall = boxWidth < 30 || boxHeight < 20;

      // Update position calculations
      double leftPosition = result[1] * factorX;
      double topPosition = result[0] * factorY;

      idx++; // Increment index after accessing both plate_numbers and boxConfs

      return Positioned(
        left: leftPosition,
        top: topPosition,
        width: boxWidth,
        height: boxHeight,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: borderColor, width: 2.0),
          ),
          child: isBoxTooSmall
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4.0, vertical: 1.0),
                      decoration: BoxDecoration(
                        color: labelBackgroundColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(2.0),
                          bottomRight: Radius.circular(2.0),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "$plate_number ${(detectionResult!.boxConfs[idx - 1] * 100).toStringAsFixed(0)}%",
                          style: TextStyle(
                            color: labelTextColor,
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
    }).toList();
  }
}
