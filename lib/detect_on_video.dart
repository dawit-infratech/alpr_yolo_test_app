import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:demo_app/service/detection_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:image/image.dart' as img;

late List<CameraDescription> cameras;

class LiveDetectOnVideo extends StatefulWidget {
  final FlutterVision vision;
  const LiveDetectOnVideo({super.key, required this.vision});

  @override
  State<LiveDetectOnVideo> createState() => _LiveDetectOnVideoState();
}

class _LiveDetectOnVideoState extends State<LiveDetectOnVideo> {
  late WebSocketChannel _channel;
  late CameraController controller;
  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;
  bool isChannelConnected = false;

  List<Map<String, dynamic>> yoloResults = [];
  List<DetectionResult> recognitionResults = [];
  List<List<List<int>>> listOfRecognitionCrops = [];

  StreamController<CameraImage> frameStreamController =
      StreamController<CameraImage>();
  StreamSubscription? frameSubscription;

  // Frame rate control
  final int targetFPS = 5;
  int frameCount = 0;
  late DateTime lastFrameTime;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    await connectSocket();
    cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    await controller.initialize();
    await loadYoloModel();
    setState(() {
      isLoaded = true;
      isDetecting = false;
      isChannelConnected = true;
    });
    setupFrameProcessing();
  }

  Future<void> connectSocket() async {
    try {
      _channel =
          WebSocketChannel.connect(Uri.parse('ws://localhost:8000/live/'));
      _channel.stream.listen(
        (message) {
          debugPrint("Received socket message: $message");
          try {
            final results = (jsonDecode(message) as List)
                .map((item) => DetectionResult.fromJson(item))
                .toList();
            setState(() {
              recognitionResults = results;
              if (listOfRecognitionCrops.length > 1) {
                listOfRecognitionCrops.removeAt(0);
              }
            });
          } catch (e) {
            debugPrint("Failed to parse message: $e");
          }
        },
        onDone: () {
          debugPrint("WebSocket closed");
          setState(() {
            isChannelConnected = false;
          });
        },
        onError: (error) {
          debugPrint("WebSocket error: $error");
          setState(() {
            isChannelConnected = false;
          });
        },
      );
      setState(() {
        isChannelConnected = true;
        debugPrint("Connected to WebSocket");
      });
    } catch (e) {
      debugPrint("Failed to connect to WebSocket: $e");
      setState(() {
        isChannelConnected = false;
      });
    }
  }

  Future<void> loadYoloModel() async {
    await widget.vision.loadYoloModel(
      labels: 'assets/models/labels.txt',
      modelPath: 'assets/models/vehicle_detect_best_yolov8n_int8_128.tflite',
      modelVersion: "yolov8",
      quantization: true,
      numThreads: 2,
      useGpu: false,
    );
  }

  void setupFrameProcessing() {
    frameSubscription = frameStreamController.stream.asyncMap((frame) async {
      final yoloResult = await processYoloFrame(frame);
      if (yoloResult.isNotEmpty) {
        await sendFrameToWebSocket(frame, yoloResult);
      }
      return yoloResult;
    }).listen((result) {
      setState(() {
        yoloResults = result;
      });
    });
  }

  Future<List<Map<String, dynamic>>> processYoloFrame(CameraImage frame) async {
    final result = await widget.vision.yoloOnFrame(
      bytesList: frame.planes.map((plane) => plane.bytes).toList(),
      imageHeight: frame.height,
      imageWidth: frame.width,
      iouThreshold: 0.4,
      confThreshold: 0.4,
      classThreshold: 0.5,
    );
    return result;
  }

  Future<void> sendFrameToWebSocket(
      CameraImage frame, List<Map<String, dynamic>> detections) async {
    if (!isChannelConnected) return;

    List<List<int>> cropBoxes = detections.map((r) {
      List<num> box = r["box"];
      return [
        box[0].toInt(),
        box[1].toInt(),
        (box[2] - box[0]).toInt(),
        (box[3] - box[1]).toInt(),
      ];
    }).toList();

    List<String> imageStrings = [];
    for (List<int> cropBox in cropBoxes) {
      final img.Image convertedImage = convertToImage(frame, cropBox);
      Uint8List imageData = Uint8List.fromList(img.encodeJpg(convertedImage));
      String base64Image = base64Encode(imageData);
      imageStrings.add(base64Image);
    }

    if (imageStrings.isNotEmpty) {
      _channel.sink.add(jsonEncode({'data': imageStrings}));
      setState(() {
        listOfRecognitionCrops.add(cropBoxes);
      });
    }
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
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
        ...displayBoxesAroundVehicles(size),
        ...displayBoxesAroundPlates(size),
        Positioned(
          bottom: 75,
          width: MediaQuery.of(context).size.width,
          child: Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                width: 5,
                color: Colors.white,
                style: BorderStyle.solid,
              ),
            ),
            child: IconButton(
              onPressed: toggleDetection,
              icon: Icon(
                isDetecting ? Icons.stop : Icons.play_arrow,
                color: isDetecting ? Colors.red : Colors.white,
              ),
              iconSize: 50,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> displayDetectionBoxes(Size screen) {
    List<Widget> boxes = [];
    boxes.addAll(displayBoxesAroundVehicles(screen));
    boxes.addAll(displayBoxesAroundPlates(screen));
    return boxes;
  }

  void toggleDetection() {
    if (isDetecting) {
      stopDetection();
    } else {
      startDetection();
    }
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
      frameCount = 0;
      lastFrameTime = DateTime.now();
    });
    await controller.startImageStream((image) {
      if (isDetecting) {
        final now = DateTime.now();
        if (now.difference(lastFrameTime).inMilliseconds >=
            (1000 / targetFPS)) {
          cameraImage = image;
          frameStreamController.add(image);
          frameCount++;
          lastFrameTime = now;
        }
      }
    });
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
      recognitionResults.clear();
    });
    await controller.stopImageStream();
  }

  @override
  void dispose() {
    frameSubscription?.cancel();
    frameStreamController.close();
    controller.dispose();
    if (isChannelConnected) {
      _channel.sink.close();
    }
    super.dispose();
  }

  List<Widget> displayBoxesAroundPlates(Size screen) {
    // debugPrint("recognition saved: $recognition_results");

    if (listOfRecognitionCrops.isEmpty ||
        listOfRecognitionCrops.first.length != recognitionResults.length) {
      return [];
    }
    debugPrint(
        "to paint: ${listOfRecognitionCrops.first.length} vs ${recognitionResults.length} \n first: ${listOfRecognitionCrops.first}");

    double factorX = screen.width / (cameraImage?.height ?? 1);
    double factorY = screen.height / (cameraImage?.width ?? 1);

    Color borderColor = const Color(0xFF2C3E50); // Dark blue-gray
    Color labelBackgroundColor = const Color(0xFF34495E); // Lighter blue-gray
    Color labelTextColor = Colors.white;

    List<Widget> boxes = [];
    List<List<int>> cropBoxes = listOfRecognitionCrops.first;
    debugPrint("recognition saved: ${recognitionResults.first.boxesXyxy}");
    debugPrint("saved recognitions: $recognitionResults");
    int cropBoxIdx = 0;
    recognitionResults.forEach((results) {
      int idx = 0;
      debugPrint("recognition saved drawing: ${results.boxesXyxy}");
      final widgets = results.boxesXyxy.map((result) {
        List<int> cropBox = cropBoxes[cropBoxIdx];

        String plate_number = results.plate_numbers[idx];

        // position calculations
        double boxWidth = (result[2] - result[0]) * factorX;
        double boxHeight = (result[3] - result[1]) * factorY;
        bool isBoxTooSmall = boxWidth < 30 || boxHeight < 20;

        double leftPosition = (result[0] + cropBox[0]) * factorX;
        double topPosition = (result[1] + cropBox[1]) * factorY;

        idx++;
        // Increment index after accessing both [plate_numbers] and [boxConfs]

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
                            "$plate_number ${(results.boxConfs[idx - 1] * 100).toStringAsFixed(0)}%",
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
      });

      boxes.addAll(widgets);
      cropBoxIdx++;
    });

    return boxes;
  }

  List<Widget> displayBoxesAroundVehicles(Size screen) {
    if (yoloResults.isEmpty) return [];

    double factorX = screen.width / (cameraImage?.height ?? 1);
    double factorY = screen.height / (cameraImage?.width ?? 1);

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

  img.Image convertToImage(CameraImage image, List<int>? cropBox) {
    final int width = image.width;
    final int height = image.height;
    final img.Image imgImage = img.Image(width, height);

    if (image.format.group == ImageFormatGroup.yuv420) {
      final Plane planeY = image.planes[0];
      final Plane planeU = image.planes[1];
      final Plane planeV = image.planes[2];

      final int uvRowStride = planeU.bytesPerRow;
      final int uvPixelStride = planeU.bytesPerPixel!;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
          final int index = y * width + x;

          final int yp = planeY.bytes[index];
          final int up = planeU.bytes[uvIndex];
          final int vp = planeV.bytes[uvIndex];

          int r = (yp + 1.402 * (vp - 128)).round();
          int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round();
          int b = (yp + 1.772 * (up - 128)).round();

          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          imgImage.setPixel(x, y, img.getColor(r, g, b));
        }
      }
    }

    // Rotate image based on orientation
    img.Image rotatedImage = img.copyRotate(imgImage, 90);
    if (cropBox != null) {
      int x = cropBox[0];
      int y = cropBox[1];
      int w = cropBox[2];
      int h = cropBox[3];

      // Crop image
      rotatedImage = img.copyCrop(rotatedImage, x, y, w, h);
    }
    // switch (controller.value.lockedCaptureOrientation) {
    //   case DeviceOrientation.portraitUp:
    //     rotatedImage = img.copyRotate(imgImage, 90); // 90 degrees clockwise
    //     break;
    //   case DeviceOrientation.portraitDown:
    //     rotatedImage =
    //         img.copyRotate(imgImage, -90); // 90 degrees counter-clockwise
    //     break;
    //   case DeviceOrientation.landscapeLeft:
    //     // rotatedImage = img.copyRotate(imgImage, 0); // No rotation needed
    //     rotatedImage = imgImage;
    //     break;
    //   case DeviceOrientation.landscapeRight:
    //     rotatedImage = img.copyRotate(imgImage, 180); // 180 degrees
    //     break;
    //   default:
    //     rotatedImage = imgImage; // Default, no rotation
    //     break;
    // }

    return rotatedImage;
  }
}
