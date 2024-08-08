import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:demo_app/service/detection_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:image/image.dart' as img;

late List<CameraDescription> cameras;

class DetectOnVideo extends StatefulWidget {
  final FlutterVision vision;
  const DetectOnVideo({Key? key, required this.vision}) : super(key: key);

  @override
  State<DetectOnVideo> createState() => _DetectOnVideoState();
}

class _DetectOnVideoState extends State<DetectOnVideo> {
  late WebSocketChannel _channel;

  late CameraController controller;
  late List<Map<String, dynamic>> yoloResults;
  late List<DetectionResult> recognition_results;
  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;
  bool isChannelConnected = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    await connectSocket();

    cameras = await availableCameras();

    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((value) {
      loadYoloModel().then((value) {
        setState(() {
          isLoaded = true;
          isDetecting = false;
          isChannelConnected = true;
          yoloResults = [];
        });
      });
    });
  }

  Future<void> connectSocket() async {
    try {
      _channel =
          WebSocketChannel.connect(Uri.parse('ws://localhost:8000/live/'));
      // await _channel.ready;
      _channel.stream.listen(
        (message) {
          debugPrint("Received socket message: $message");
          try {
            final result = DetectionResult.fromJson(message);
            setState(() {
              recognition_results.add(result);
            });
          } catch (e) {
            debugPrint("Failed to parse message: $e");
          }
        },
        onDone: () {
          debugPrint("WebSocket closed");
          // setState(() {
          //   isChannelConnected = false;
          // });
        },
        onError: (error) {
          debugPrint("WebSocket error: $error");
          // setState(() {
          //   isChannelConnected = false;
          // });
        },
      );
      // setState(() {
      isChannelConnected = true;
      debugPrint("Connected to WebSocket");
      // });
    } catch (e) {
      debugPrint("Failed to connect to WebSocket: $e");
      // setState(() {
      //   isChannelConnected = false;
      // });
    }
  }

  @override
  void dispose() async {
    super.dispose();
    controller.dispose();

    if (isChannelConnected) {
      _channel.sink.close();
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
          child: CameraPreview(
            controller,
          ),
        ),
        ...displayBoxesAroundRecognizedObjects(size),
        Positioned(
          bottom: 75,
          width: MediaQuery.of(context).size.width,
          child: Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  width: 5, color: Colors.white, style: BorderStyle.solid),
            ),
            child: isDetecting
                ? IconButton(
                    onPressed: () async {
                      stopDetection();
                    },
                    icon: const Icon(
                      Icons.stop,
                      color: Colors.red,
                    ),
                    iconSize: 50,
                  )
                : IconButton(
                    onPressed: () async {
                      await startDetection();
                    },
                    icon: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                    ),
                    iconSize: 50,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> loadYoloModel() async {
    await widget.vision.loadYoloModel(
        labels: 'assets/models/labels.txt',
        // modelPath: 'assets/models/vehicle_detect_best_int8_128.tflite',
        modelPath: 'assets/models/vehicle_detect_best_yolov8n_int8_128.tflite',
        modelVersion: "yolov8",
        quantization: true,
        numThreads: 2,
        useGpu: false);
    setState(() {
      isLoaded = true;
    });
  }

  // Timer? _emptyResultTimer;
  DateTime? _lastNonEmptyResultTime;

  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    final result = await widget.vision.yoloOnFrame(
        bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
        imageHeight: cameraImage.height,
        imageWidth: cameraImage.width,
        iouThreshold: 0.4,
        confThreshold: 0.4,
        classThreshold: 0.5);

    if (result.isNotEmpty) {
      _lastNonEmptyResultTime = DateTime.now();
      setState(() {
        yoloResults = result;
      });
      if (isChannelConnected) {
        processImage(cameraImage);
        // _channel.sink.add(jsonEncode({
        //   'width': cameraImage.width,
        //   'height': cameraImage.height,
        //   'data': base64Encode(cameraImage.planes.first.bytes)
        // }));
        debugPrint("Sending image to websocket server");
      }
    } else {
      if (_lastNonEmptyResultTime != null &&
          DateTime.now().difference(_lastNonEmptyResultTime!).inSeconds > 1) {
        setState(() {
          yoloResults = [];
        });
      }
    }
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    if (controller.value.isStreamingImages) {
      return;
    }
    await controller.startImageStream((image) async {
      if (isDetecting) {
        cameraImage = image;
        yoloOnFrame(image);
      }
    });
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
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

  Future<void> processImage(CameraImage image) async {
    final img.Image convertedImage = convertToImage(image);
    final bytes = Uint8List.fromList(img.encodeJpg(convertedImage));

    // final message = jsonEncode({
    //   'width': image.width,
    //   'height': image.height,
    //   'data': base64Encode(bytes),
    // });
    if (isChannelConnected) {
      _channel.sink.add(bytes);
      debugPrint("Sent image data with dimensions");
    }
  }

  img.Image convertToImage(CameraImage image) {
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

    return imgImage;
  }
}
