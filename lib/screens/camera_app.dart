import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:demo_app/object_painter.dart';
import 'package:demo_app/requests/requests.dart';
import 'package:demo_app/screens/show_image.dart';
import 'package:demo_app/service/detection_result.dart';
import 'package:demo_app/service/detection_service.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_vision/flutter_vision.dart';
import 'package:gap/gap.dart';
import 'package:media_scanner/media_scanner.dart';

class CameraApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraApp({super.key, required this.cameras});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  // late FlutterVision _vision;

  late CameraController cameraController;
  late Future<void> cameraValue;
  List<File> imagesList = [];
  bool isFlashOn = false;
  bool isRearCamera = true;
  bool _isDetecting = false;
  late CameraImage cameraImage;

  DetectionResult? detectionResult;
  // List<Map<String, dynamic>> yoloResults = [];

  Future<File> saveImage(XFile image) async {
    final downloadPath = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOWNLOADS);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('$downloadPath/$fileName');

    try {
      await file.writeAsBytes(await image.readAsBytes());
      var result = await DetectionService.detectAndOcr(file);
      setState(() {
        detectionResult = result;
        debugPrint(
            "result: boxesXyxy: ${result.boxesXyxy}, ocrTexts: ${result.ocrTexts}, ocrConfs: ${result.ocrConfs}");
      });
    } catch (error) {
      debugPrint("error: $error");
    }

    return file;
  }

  Future<String?> takePicture() async {
    if (cameraController.value.isTakingPicture ||
        !cameraController.value.isInitialized) {
      return null;
    }

    if (isFlashOn == false) {
      await cameraController.setFlashMode(FlashMode.off);
    } else {
      await cameraController.setFlashMode(FlashMode.torch);
    }
    final image = await cameraController.takePicture();

    if (cameraController.value.flashMode == FlashMode.torch) {
      setState(() {
        cameraController.setFlashMode(FlashMode.off);
      });
    }

    final file = await saveImage(image);
    debugPrint("imagePath: ${file.path}");

    setState(() {
      imagesList.add(file);
    });

    MediaScanner.loadMedia(path: file.path);
    return file.path;
  }

  void startCamera(int camera) {
    cameraController = CameraController(
      widget.cameras[camera],
      ResolutionPreset.max,
      enableAudio: false,
    );
    cameraValue = cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      cameraController.startImageStream((image) => objectDetector(image));
    });
  }

  // Future<void> _initializeVision() async {
  //   _vision = FlutterVision();
  //   int optimalThreadCount = getOptimalThreadCount();
  //   debugPrint("optimalThreadCount: $optimalThreadCount");

  //   await _vision.loadYoloModel(
  //     labels: 'assets/models/labels.txt',
  //     modelPath: 'assets/models/best_float32.tflite',
  //     modelVersion: 'yolov8',
  //     numThreads: optimalThreadCount,
  //     useGpu: false,
  //   );
  // }

  @override
  void initState() {
    super.initState();
    startCamera(0);
    // _initializeVision();
  }

  @override
  void dispose() {
    cameraController.dispose();
    // _vision.closeYoloModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromRGBO(255, 255, 255, .7),
        shape: const CircleBorder(),
        onPressed: () {
          takePicture().then((value) {
            if (value != null) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ShowImage(
                          imagePath: value, detectionResult: detectionResult)));
            }
          });
        },
        child: const Icon(
          Icons.camera_alt,
          size: 40,
          color: Colors.black87,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Stack(
        children: [
          FutureBuilder(
            future: cameraValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return SizedBox(
                  width: size.width,
                  height: size.height,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: 100,
                      child: CameraPreview(cameraController),
                    ),
                  ),
                );
              } else {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          ),
          // if (yoloResults.isNotEmpty)
          //   CustomPaint(
          //     painter: ObjectDetectionPainter(
          //         yoloResults,
          //         Size(
          //           cameraController.value.previewSize!.width,
          //           cameraController.value.previewSize!.height,
          //         )),
          //     child: Container(),
          //   ),
          // if (yoloResults.isNotEmpty)
          //   CustomPaint(
          //     painter: ObjectPainter(
          //       yoloResults,
          //       cameraController.value.previewSize!.width.toDouble(),
          //       cameraController.value.previewSize!.height.toDouble(),
          //       size,
          //     ),
          //   ),

          // if (yoloResults.isNotEmpty)
          // CustomPaint(
          // painter:
          // ObjectPainter(yoloResults, cameraImage.width.toDouble(),
          // cameraImage.height.toDouble(), size),
          //   child:
          //       Container(), // This ensures the CustomPaint covers the screen
          // ),
          ...displayBoxesAroundRecognizedObjects(size),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 5, top: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isFlashOn = !isFlashOn;
                        });
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(50, 0, 0, 0),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: isFlashOn
                              ? const Icon(
                                  Icons.flash_on,
                                  color: Colors.white,
                                  size: 30,
                                )
                              : const Icon(
                                  Icons.flash_off,
                                  color: Colors.white,
                                  size: 30,
                                ),
                        ),
                      ),
                    ),
                    const Gap(10),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isRearCamera = !isRearCamera;
                        });
                        isRearCamera ? startCamera(0) : startCamera(1);
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(50, 0, 0, 0),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: isRearCamera
                              ? const Icon(
                                  Icons.camera_rear,
                                  color: Colors.white,
                                  size: 30,
                                )
                              : const Icon(
                                  Icons.camera_front,
                                  color: Colors.white,
                                  size: 30,
                                ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 7, bottom: 75),
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: imagesList.length,
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (BuildContext context, int index) {
                          return Padding(
                            padding: const EdgeInsets.all(2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image(
                                height: 100,
                                width: 100,
                                opacity: const AlwaysStoppedAnimation(0.7),
                                image: FileImage(
                                  File(imagesList[index].path),
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // int getOptimalThreadCount() {
  //   int processorCount = Platform.numberOfProcessors;
  //   return max(1, processorCount ~/ 2);
  // }

  void objectDetector(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;
    try {
      // var result = await DetectionService.detectAndOcr(image);

      // final result = await _vision.yoloOnFrame(
      //   bytesList: image.planes.map((plane) => plane.bytes).toList(),
      //   imageHeight: image.height,
      //   imageWidth: image.width,
      //   iouThreshold: 0.4,
      //   confThreshold: 0.4,
      //   classThreshold: 0.5,
      // );
      if (mounted) {
        setState(() {
          // yoloResults = result;
          cameraImage = image;
        });
      }
      // debugPrint('yoloResults is ${yoloResults.length}. Result: $result');
    } catch (e) {
      debugPrint("Error in object detection: $e");
    }
    _isDetecting = false;
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size size) {
    if (detectionResult == null) return [];

    return detectionResult!.nBoxesXyxy.asMap().entries.map((entry) {
      final index = entry.key;
      final box = entry.value;
      final text = detectionResult?.ocrTexts[index] ?? "";
      final conf = detectionResult?.ocrConfs[index] ?? 0;

      return Positioned(
        left: box[0] * size.width,
        top: box[1] * size.height,
        width: (box[2] - box[0]) * size.width,
        height: (box[3] - box[1]) * size.height,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red, width: 2),
          ),
          child: Text(
            '$text (${conf.toStringAsFixed(2)})',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }).toList();
  }
}

// class ObjectDetectionPainter extends CustomPainter {
//   final List<Map<String, dynamic>> detections;
//   final Size imageSize;

//   ObjectDetectionPainter(this.detections, this.imageSize);

//   @override
//   void paint(Canvas canvas, Size size) {
//     // final Size imgSize = Size(width, height)
//     final double scaleX = size.width / imageSize.width;
//     final double scaleY = size.height / imageSize.height;

//     final Paint paint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.0
//       ..color = Colors.pink;

//     for (var detection in detections) {
//       final double left = detection["box"][0] * scaleX;
//       final double top = detection["box"][1] * scaleY;
//       final double right = detection["box"][2] * scaleX;
//       final double bottom = detection["box"][3] * scaleY;

//       canvas.drawRect(
//         Rect.fromLTRB(left, top, right, bottom),
//         paint,
//       );

//       TextPainter(
//         text: TextSpan(
//           text:
//               "${detection['tag']} ${(detection['box'][4] * 100).toStringAsFixed(0)}%",
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 12,
//             backgroundColor: Colors.pink,
//           ),
//         ),
//         textDirection: TextDirection.ltr,
//       )
//         ..layout()
//         ..paint(canvas, Offset(left, top));
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }
