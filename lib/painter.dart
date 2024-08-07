// import 'package:flutter/material.dart';

// List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
//   if (yoloResults.isEmpty) return [];
  
//   double factorX = screen.width / (cameraImage.height);
//   double factorY = screen.height / (cameraImage.width);
  
//   // Professional color scheme
//   Color borderColor = const Color(0xFF2C3E50);  // Dark blue-gray
//   Color labelBackgroundColor = const Color(0xFF34495E);  // Lighter blue-gray
//   Color labelTextColor = Colors.white;

//   return yoloResults.map((result) {
//     return Positioned(
//       left: result["box"][0] * factorX,
//       top: result["box"][1] * factorY,
//       width: (result["box"][2] - result["box"][0]) * factorX,
//       height: (result["box"][3] - result["box"][1]) * factorY,
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(4.0),  // Less rounded corners
//           border: Border.all(color: borderColor, width: 2.0),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
//               decoration: BoxDecoration(
//                 color: labelBackgroundColor,
//                 borderRadius: const BorderRadius.only(
//                   topLeft: Radius.circular(2.0),
//                   bottomRight: Radius.circular(2.0),
//                 ),
//               ),
//               child: Text(
//                 "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
//                 style: TextStyle(
//                   color: labelTextColor,
//                   fontSize: 12.0,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }).toList();
// }