import 'dart:io';
import 'dart:typed_data';

import 'package:demo_app/services/models/lpr_result.dart';
import 'package:demo_app/services/lpr_service.dart';
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
  LPRResult recognitionResults = LPRResult(
      boxConfs: [], plateNumbers: [], normalizedBoxesXyxy: [], boxesXyxy: []);

  bool isDetecting = false;

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
              isDetecting
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isDetecting = true;
                        });
                        yoloOnImage();
                      },
                      child: const Text("Detect"),
                    ),
            ],
          ),
        ),
        ...displayBoxesAroundRecognizedVehicles(size),
        ...displayBoxesAroundPlates(size),
      ],
    );
  }

  Future<void> loadYoloModel() async {
    await widget.vision.loadYoloModel(
        labels: 'assets/models/labels.txt',
        modelPath: 'assets/models/vehicle_detect_best_yolov8n_int8_128.tflite',
        modelVersion: "yolov8",
        quantization: true,
        numThreads: 2,
        useGpu: false);

    /// Increase the number of threads if you have a powerful device. You can use the [getOptimalThreadCount] method
    /// implementation from [camera_app.dart] to get the optimal number of threads for the device.
    /// Also you can set the [useGpu] to true if the device can open a GPU delegate.
    /// You can also set the [quantization] to false if you want the model to be more accurate in its detection. But this
    /// might decrease the performance speed.

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
        // Clear the previous results
        yoloResults.clear();
        recognitionResults = LPRResult(
            boxConfs: [],
            plateNumbers: [],
            normalizedBoxesXyxy: [],
            boxesXyxy: []);
        // Set the new image file
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
      /// If the result of the vehicle detection from the yolo model is not empty,
      /// then we will try to read the plate number by connecting to the server
      /// with the License Plate Recognition service [LPRService].

      LPRResult recognitionResponse;

      try {
        recognitionResponse =
            await LPRService.detectAndReadFromFile(imageFile!);
      } catch (e) {
        recognitionResponse = LPRResult(
            boxConfs: [],
            plateNumbers: [],
            normalizedBoxesXyxy: [],
            boxesXyxy: []);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Not connected to Server for plate Recognition!'),
        ));
      }

      setState(() {
        yoloResults = result;
        recognitionResults = recognitionResponse;
        isDetecting = false;
      });
    } else {
      setState(() {
        yoloResults = [];
        isDetecting = false;
      });
    }
  }

  List<Widget> displayBoxesAroundRecognizedVehicles(Size screen) {
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

  List<Widget> displayBoxesAroundPlates(Size screen) {
    debugPrint("recognition saved: $recognitionResults");
    if (recognitionResults.normalizedBoxesXyxy.isEmpty) {
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

    return recognitionResults.boxesXyxy.map((result) {
      double boxWidth = (result[2] - result[0]) * factorX;
      double boxHeight = (result[3] - result[1]) * factorY;

      // Determine if the box is too small to show the label
      bool isBoxTooSmall = boxWidth < 30 || boxHeight < 20;
      String plateNumber = recognitionResults.plateNumbers[idx];

      idx++; // Increment index after accessing the plate_numbers

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
                          "$plateNumber ${(recognitionResults.boxConfs[idx - 1] * 100).toStringAsFixed(0)}%",
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
