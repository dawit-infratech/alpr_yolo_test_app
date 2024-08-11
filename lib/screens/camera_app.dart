import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:demo_app/detect_on_image.dart';
import 'package:demo_app/detect_on_video.dart';
import 'package:demo_app/main.dart';
import 'package:demo_app/screens/show_image.dart';

import 'package:demo_app/service/detection_result.dart';
import 'package:demo_app/service/detection_service.dart';
// import 'package:demo_app/service/detection_service.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_vision/flutter_vision.dart';
// import 'package:flutter_vision/flutter_vision.dart';
import 'package:gap/gap.dart';
import 'package:media_scanner/media_scanner.dart';

enum Options { none, image, frame, vision }

class CameraApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraApp({super.key, required this.cameras});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late FlutterVision _vision;
  Options option = Options.none;

  late CameraController cameraController;
  late Future<void> cameraValue;
  List<File> imagesList = [];
  bool isFlashOn = false;
  bool isRearCamera = true;
  bool _isDetecting = false;
  late CameraImage cameraImage;

  DetectionResult? detectionResult;
  List<Map<String, dynamic>> yoloResults = [];

  Future<File> saveImage(XFile image) async {
    final downloadPath = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_PICTURES);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('$downloadPath/$fileName');

    try {
      debugPrint("saving on imagePath: ${image.path}");
      await file.writeAsBytes(await image.readAsBytes());
      var result = await DetectionService.detectAndReadFromFile(file);
      setState(() {
        detectionResult = result;
        debugPrint("result: $result");
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
      ResolutionPreset.medium,
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

  Future<void> _initializeVision() async {
    _vision = FlutterVision();
    int optimalThreadCount = getOptimalThreadCount();
    debugPrint("optimalThreadCount: $optimalThreadCount");

    await _vision.loadYoloModel(
      labels: 'assets/models/labels.txt',
      // modelPath: 'assets/models/vehicle_detect_best_int8_128.tflite',
      modelPath: 'assets/models/vehicle_detect_best_yolov8n_int8_128.tflite',

      modelVersion: 'yolov8',
      quantization: true,
      numThreads: optimalThreadCount,
      useGpu: false,
    );
  }

  @override
  void initState() {
    super.initState();
    startCamera(0);
    _initializeVision();
  }

  @override
  void dispose() {
    cameraController.dispose();
    _vision.closeYoloModel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: task(option, context),
      floatingActionButton: SpeedDial(
        //margin bottom
        icon: Icons.open_in_new, //icon on Floating action button
        activeIcon: Icons.close, //icon when menu is expanded on button
        backgroundColor: Colors.deepOrangeAccent, //background color of button
        foregroundColor: Colors.white, //font color, icon color in button
        activeBackgroundColor:
            Colors.deepPurpleAccent, //background color when menu is expanded
        activeForegroundColor: Colors.white,
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        buttonSize: const Size(56.0, 56.0),
        children: [
          SpeedDialChild(
            //speed dial child
            child: const Icon(Icons.camera),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            label: 'From Camera',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MainApp(cameras: widget.cameras)));
              // setState(() {
              //   option = Options.none;
              // });
            },
          ),
          SpeedDialChild(
            //speed dial child
            child: const Icon(Icons.video_call),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            label: 'From Video',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () {
              setState(() {
                option = Options.frame;
              });
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.image),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            label: 'From Gallery',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () {
              setState(() {
                option = Options.image;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget task(Options option, BuildContext context) {
    if (option == Options.frame) {
      return LiveDetectOnVideo(vision: _vision);
    }

    if (option == Options.image) {
      return DetectOnImage(vision: _vision);
    }

    return cameraBody(context);

    // return const Center(child: Text("Choose Task"));
  }

  Widget cameraBody(BuildContext context) {
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
        fit: StackFit.expand,
        children: [
          FutureBuilder(
            future: cameraValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return AspectRatio(
                    aspectRatio: cameraController.value.aspectRatio,
                    child: CameraPreview(cameraController));
              } else {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          ),
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

  int getOptimalThreadCount() {
    int processorCount = Platform.numberOfProcessors;
    return max(1, processorCount ~/ 2);
  }

  void objectDetector(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;
    try {
      final result = await _vision.yoloOnFrame(
        bytesList: image.planes.map((plane) => plane.bytes).toList(),
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.4,
        confThreshold: 0.4,
        classThreshold: 0.5,
      );
      if (mounted) {
        setState(() {
          yoloResults = result;
          cameraImage = image;
        });
      }
      debugPrint('yoloResults is ${yoloResults.length}. Result: $result');
    } catch (e) {
      debugPrint("Error in object detection: $e");
    }
    _isDetecting = false;
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];

    double factorX = screen.width / (cameraImage.height);
    double factorY = screen.height / (cameraImage.width);

    Color borderColor = const Color(0xFF2C3E50); // Dark blue-gray
    Color labelBackgroundColor = const Color(0xFF34495E); // Lighter blue-gray
    Color labelTextColor = Colors.white;

    return yoloResults.map((result) {
      double boxWidth = (result["box"][2] - result["box"][0]) * factorX;
      double boxHeight = (result["box"][3] - result["box"][1]) * factorY;

      bool isBoxTooSmall = boxWidth < 30 || boxHeight < 20;

      return Positioned(
        left: result["box"][0] * factorX,
        top: result["box"][1] * factorY,
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
                          "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
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
