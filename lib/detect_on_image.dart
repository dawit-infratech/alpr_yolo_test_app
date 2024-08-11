import 'dart:io';
import 'dart:typed_data';

import 'package:demo_app/service/detection_result.dart';
import 'package:demo_app/service/detection_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image_picker/image_picker.dart';

class DetectOnImage extends StatefulWidget {
  final FlutterVision vision;
  const DetectOnImage({super.key, required this.vision});

  @override
  State<DetectOnImage> createState() => _DetectOnImageState();
}

class _DetectOnImageState extends State<DetectOnImage> {
  late List<Map<String, dynamic>> yoloResults;
  File? imageFile;
  int imageHeight = 1;
  int imageWidth = 1;
  bool isLoaded = false;
  DetectionResult recognition_results = DetectionResult(
      boxConfs: [], plate_numbers: [], normalizedBoxesXyxy: [], boxesXyxy: []);

  @override
  void initState() {
    super.initState();
    loadYoloModel().then((value) {
      setState(() {
        yoloResults = [];
        isLoaded = true;
      });
    });
  }

  @override
  void dispose() async {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: Text("Model not loaded, waiting for it"),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        imageFile != null ? Image.file(imageFile!) : const SizedBox(),
        Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: pickImage,
                child: const Text("Pick an image"),
              ),
              ElevatedButton(
                onPressed: yoloOnImage,
                child: const Text("Detect"),
              )
            ],
          ),
        ),
        ...displayBoxesAroundRecognizedObjects(size),
        ...displayBoxesAroundPlates(size),
      ],
    );
  }

  Future<void> loadYoloModel() async {
    await widget.vision.loadYoloModel(
        labels: 'assets/models/labels.txt',
        // modelPath: 'assets/models/vehicle_detect_best_int8_128.tflite',
        modelPath: 'assets/models/vehicle_detect_best_yolov8n_int8_128.tflite',
        modelVersion: "yolov8",
        quantization: false,
        numThreads: 2,
        useGpu: false);
    setState(() {
      isLoaded = true;
    });
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Capture a photo
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        imageFile = File(photo.path);
      });
    }
  }

  yoloOnImage() async {
    yoloResults.clear();
    Uint8List byte = await imageFile!.readAsBytes();
    final image = await decodeImageFromList(byte);
    imageHeight = image.height;
    imageWidth = image.width;
    final result = await widget.vision.yoloOnImage(
        bytesList: byte,
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.8,
        confThreshold: 0.4,
        classThreshold: 0.5);
    if (result.isNotEmpty) {
      // await imageFile?.writeAsBytes(await image.readAsBytes());
      DetectionResult detection_response =
          await DetectionService.detectAndReadFromFile(imageFile!);
      setState(() {
        yoloResults = result;
        recognition_results = detection_response;
      });
    } else {
      setState(() {
        yoloResults = [];
      });
    }
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];

    double factorX = screen.width / imageWidth;
    double imgRatio = imageWidth / imageHeight;
    double newWidth = imageWidth * factorX;
    double newHeight = newWidth / imgRatio;
    double factorY = newHeight / imageHeight;

    double pady = (screen.height - newHeight) / 2;

    Color borderColor = const Color(0xFF2C3E50); // Dark blue-gray
    Color labelBackgroundColor = const Color(0xFF34495E); // Lighter blue-gray
    Color labelTextColor = Colors.white;

    return yoloResults.map((result) {
      double boxWidth = (result["box"][2] - result["box"][0]) * factorX;
      double boxHeight = (result["box"][3] - result["box"][1]) * factorY;

      // Determine if the box is too small to show the label
      bool isBoxTooSmall = boxWidth < 30 || boxHeight < 20;

      return Positioned(
        left: result["box"][0] * factorX,
        top: result["box"][1] * factorY + pady,
        width: boxWidth,
        height: boxHeight,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.0), // Less rounded corners
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

  List<Widget> displayBoxesAroundPlates(Size screen) {
    if (recognition_results == null) {
      return [];
    }
    debugPrint("recognition saved: ${recognition_results}");
    if (recognition_results!.normalizedBoxesXyxy.isEmpty) {
      return [];
    }

    double factorX = screen.width / imageWidth;
    double imgRatio = imageWidth / imageHeight;
    double newWidth = imageWidth * factorX;
    double newHeight = newWidth / imgRatio;
    double factorY = newHeight / imageHeight;

    double pady = (screen.height - newHeight) / 2;

    Color borderColor = const Color(0xFF2C3E50); // Dark blue-gray
    Color labelBackgroundColor = const Color(0xFF34495E); // Lighter blue-gray
    Color labelTextColor = Colors.white;
    int idx = 0;

    return recognition_results!.boxesXyxy.map((result) {
      double boxWidth = (result[2] - result[0]) * factorX;
      double boxHeight = (result[3] - result[1]) * factorY;

      // Determine if the box is too small to show the label
      bool isBoxTooSmall = boxWidth < 30 || boxHeight < 20;
      String plate_number = recognition_results!.plate_numbers[idx];

      // // Update position calculations
      // double leftPosition = result[0] * factorX;
      // double topPosition = result[1] * factorY;

      idx++; // Increment index after accessing both plate_numbers and boxConfs

      return Positioned(
        left: result[0] * factorX,
        top: result[1] * factorY + pady,
        width: boxWidth,
        height: boxHeight,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.0), // Less rounded corners
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
                          "${plate_number} ${(recognition_results!.boxConfs[idx - 1] * 100).toStringAsFixed(0)}%",
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
