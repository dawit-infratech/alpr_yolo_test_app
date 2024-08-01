import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ObjectPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final double previewWidth;
  final double previewHeight;
  final Size screenSize;
  // final List<Map<String, dynamic>> yoloResults;

  ObjectPainter(
    this.detections,
    this.previewWidth,
    this.previewHeight,
    this.screenSize,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // double factorX = screenSize.width / (previewHeight ?? 1);
    // double factorY = screenSize.height / (previewWidth ?? 1);

    // Color colorPick = const Color.fromARGB(255, 50, 233, 30);
    // return yoloResults.map((result) {
    //   return Positioned(
    //     left: result["box"][0] * factorX,
    //     top: result["box"][1] * factorY,
    //     width: (result["box"][2] - result["box"][0]) * factorX,
    //     height: (result["box"][3] - result["box"][1]) * factorY,
    //     child: Container(
    //       decoration: BoxDecoration(
    //         borderRadius: const BorderRadius.all(Radius.circular(10.0)),
    //         border: Border.all(color: Colors.pink, width: 2.0),
    //       ),
    //       child: Text(
    //         "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
    //         style: TextStyle(
    //           background: Paint()..color = colorPick,
    //           color: Colors.white,
    //           fontSize: 18.0,
    //         ),
    //       ),
    //     ),
    //   );
    // }).toList();
    final double scaleX = screenSize.width / previewWidth;
    final double scaleY = screenSize.height / previewHeight;

    final Paint boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.pink;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final detection in detections) {
      final double left = detection["box"][0] * scaleX;
      final double top = detection["box"][1] * scaleY;
      final double right = detection["box"][2] * scaleX;
      final double bottom = detection["box"][3] * scaleY;

      // Draw bounding box
      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        boxPaint,
      );

      // Prepare text
      final String label =
          "${detection['tag']} ${(detection['box'][4] * 100).toStringAsFixed(0)}%";
      final TextSpan textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          backgroundColor: Colors.pink,
        ),
      );

      // Layout and paint text
      textPainter.text = textSpan;
      textPainter.layout();
      textPainter.paint(canvas, Offset(left, top));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// import 'package:flutter/material.dart';

// class ObjectPainter extends StatelessWidget {
//   final List<Map<String, dynamic>> detections;
//   final double previewWidth;
//   final double previewHeight;
//   final Size screenSize;

//   ObjectPainter(
//       this.detections, this.previewWidth, this.previewHeight, this.screenSize);

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: detections.map((detection) {
//         // Extract bounding box coordinates
//         final double left = detection["box"][0] * screenSize.width;
//         final double top = detection["box"][1] * screenSize.height;
//         final double right = detection["box"][2] * screenSize.width;
//         final double bottom = detection["box"][3] * screenSize.height;

//         // Calculate box dimensions
//         final double boxWidth = right - left;
//         final double boxHeight = bottom - top;

//         // Prepare label text
//         final String label =
//             "${detection['tag']} ${(detection['box'][4] * 100).toStringAsFixed(0)}%";

//         return Positioned(
//           left: left,
//           top: top,
//           width: boxWidth,
//           height: boxHeight,
//           child: Container(
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.red, width: 2.0),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   color: Colors.red,
//                   child: Padding(
//                     padding: const EdgeInsets.all(2.0),
//                     child: Text(
//                       label,
//                       style: const TextStyle(color: Colors.white, fontSize: 12),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }
// }

// import 'package:flutter/material.dart';

// class ObjectPainter extends CustomPainter {
//   final List<Map<String, dynamic>> detections;
//   final double previewWidth;
//   final double previewHeight;
//   final Size screenSize;

//   ObjectPainter(
//       this.detections, this.previewWidth, this.previewHeight, this.screenSize);

//   @override
//   void paint(Canvas canvas, Size size) {
//     // Calculate scale factors to convert preview coordinates to screen coordinates
//     final double scaleX = screenSize.width / previewWidth;
//     final double scaleY = screenSize.height / previewHeight;
//     final double scale = scaleX < scaleY ? scaleX : scaleY;

//     // Calculate offset to center the preview
//     final double offsetX = (screenSize.width - previewWidth * scale) / 2;
//     final double offsetY = (screenSize.height - previewHeight * scale) / 2;

//     // Paint settings for bounding boxes
//     final Paint boxPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.0
//       ..color = Colors.red;

//     // Paint settings for text background
//     final Paint textBackgroundPaint = Paint()
//       ..style = PaintingStyle.fill
//       ..color = Colors.red;

//     // Iterate over detections and draw bounding boxes and labels
//     for (final detection in detections) {
//       // Get bounding box coordinates
//       final double left = detection["box"][0] * scale + offsetX;
//       final double top = detection["box"][1] * scale + offsetY;
//       final double right = detection["box"][2] * scale + offsetX;
//       final double bottom = detection["box"][3] * scale + offsetY;

//       // Draw bounding box
//       canvas.drawRect(
//         Rect.fromLTRB(left, top, right, bottom),
//         boxPaint,
//       );

//       // Prepare label text
//       final String label =
//           "${detection['tag']} ${(detection['box'][4] * 100).toStringAsFixed(0)}%";
//       final TextSpan textSpan = TextSpan(
//         text: label,
//         style: const TextStyle(color: Colors.white, fontSize: 12),
//       );
//       final TextPainter textPainter = TextPainter(
//         text: textSpan,
//         textDirection: TextDirection.ltr,
//       );
//       textPainter.layout();

//       // Draw text background
//       const double textPadding = 4.0;
//       const double textHeight = 20.0;
//       canvas.drawRect(
//         Rect.fromLTWH(left, top - textHeight, textPainter.width + textPadding,
//             textHeight),
//         textBackgroundPaint,
//       );

//       // Draw text
//       textPainter.paint(
//           canvas, Offset(left + textPadding / 2, top - textHeight));
//     }
//   }

//   @override
//   bool shouldRepaint(covariant ObjectPainter oldDelegate) {
//     return oldDelegate.detections != detections ||
//         oldDelegate.screenSize != screenSize ||
//         oldDelegate.previewWidth != previewWidth ||
//         oldDelegate.previewHeight != previewHeight;
//   }
// }

// import 'package:flutter/material.dart';

// class ObjectPainter extends CustomPainter {
//   final List<Map<String, dynamic>> detections;
//   final double previewWidth;
//   final double previewHeight;
//   final Size screenSize;

//   ObjectPainter(
//       this.detections, this.previewWidth, this.previewHeight, this.screenSize);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final Paint boxPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.0
//       ..color = Colors.red;

//     final Paint textBackgroundPaint = Paint()
//       ..style = PaintingStyle.fill
//       ..color = Colors.red;

//     for (final detection in detections) {
//       final double relativeLeft = detection["box"][0] / previewWidth;
//       final double relativeTop = detection["box"][1] / previewHeight;
//       final double relativeRight = detection["box"][2] / previewWidth;
//       final double relativeBottom = detection["box"][3] / previewHeight;

//       // Calculate absolute coordinates
//       final double left = relativeLeft * screenSize.width;
//       final double top = relativeTop * screenSize.height;
//       final double right = relativeRight * screenSize.width;
//       final double bottom = relativeBottom * screenSize.height;

//       // Draw bounding box
//       canvas.drawRect(
//         Rect.fromLTRB(left, top, right, bottom),
//         boxPaint,
//       );

//       // Prepare text
//       final String label =
//           "${detection['tag']} ${(detection['box'][4] * 100).toStringAsFixed(0)}%";
//       final textSpan = TextSpan(
//         text: label,
//         style: const TextStyle(color: Colors.white, fontSize: 12),
//       );
//       final textPainter = TextPainter(
//         text: textSpan,
//         textDirection: TextDirection.ltr,
//       );
//       textPainter.layout();

//       // Draw text background
//       canvas.drawRect(
//         Rect.fromLTWH(left, top - 20, textPainter.width + 4, 20),
//         textBackgroundPaint,
//       );

//       // Draw text
//       textPainter.paint(
//         canvas,
//         Offset(left + 2, top - 20),
//       );
//     }
//   }

//   @override
//   bool shouldRepaint(covariant ObjectPainter oldDelegate) {
//     return oldDelegate.detections != detections ||
//         oldDelegate.screenSize != screenSize ||
//         oldDelegate.previewWidth != previewWidth ||
//         oldDelegate.previewHeight != previewHeight;
//   }
// }
