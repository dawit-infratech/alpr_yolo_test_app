import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:demo_app/main.dart';

import 'package:demo_app/services/models/lpr_result.dart';
import 'package:demo_app/services/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image/image.dart' as img;

late List<CameraDescription> cameras;

class LiveDetectOnVideo extends StatefulWidget {
  final FlutterVision vision;
  final List<CameraDescription> cameras;

  const LiveDetectOnVideo(
      {super.key, required this.vision, required this.cameras});

  @override
  State<LiveDetectOnVideo> createState() => _LiveDetectOnVideoState();
}

class _LiveDetectOnVideoState extends State<LiveDetectOnVideo> {
  late WebSocketManager _webSocketManager;
  late CameraController controller;
  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;
  bool _isSocketConnected = false;

  List<Map<String, dynamic>> yoloResults =
      []; // holds vehicle detection results from yolo
  List<LPRResult> recognitionResults =
      []; // holds plate recognition results from socket

  List<List<List<int>>> listOfRecognitionCrops = [];

  /// The [listOfRecognitionCrops] is a list of crop boxes around the detected plates
  /// Each crop box is a list of [x, y, w, h] where [x, y] is the top left corner of the crop box
  /// and [w, h] is the width and height of the crop box. The crop boxes are cropped from vehicle detection after the
  /// results of the tflite [yolo model] on the original image and then later used to re-construct the License Plate
  /// bounding boxes on build after the socket completes the recognition.
  /// The crop boxes had to be stored in a separate than [yoloResults] because the socket is sending the crop boxes in a separate asynchronous order than the Yolo detection.
  /// Then the [listOfRecognitionCrops] is systematically updated by removing value at index 0 whenever the socket completes another  recognition to add to the queue.

  StreamController<CameraImage> frameStreamController =
      StreamController<CameraImage>();
  StreamSubscription? frameSubscription;

  /// Frame rate control, the target FPS is set to [5 fps] for now
  final int targetFPS = 5;
  int frameCount = 0;
  late DateTime lastFrameTime;

  @override
  void initState() {
    super.initState();
    // connect to websocket on local server
    // TODO: change to server url
    _webSocketManager = WebSocketManager(
      'ws://localhost:8000/live/',
      onMessage: _handleSocketMessage,
      onStateChange: _handleSocketStateChange,
    );
    _webSocketManager.connect();
    init();
  }

  void _handleSocketMessage(dynamic message) {
    debugPrint("Received socket message: $message");
    try {
      final results = (jsonDecode(message) as List)
          .map((item) => LPRResult.fromJson(item))
          .toList();
      setState(() {
        recognitionResults = results;
        if (listOfRecognitionCrops.isNotEmpty) {
          /// remove the crop boxes at index 0 because, because they have already been used to draw boxes by the [displayBoxesAroundPlates] method
          listOfRecognitionCrops.removeAt(0);
        }
      });
    } catch (e) {
      debugPrint("Failed to parse message: $e");
    }
  }

  void _handleSocketStateChange(SocketState state) {
    setState(() {
      _isSocketConnected = state == SocketState.connected;
    });
  }

  Future<void> init() async {
    try {
      cameras = await availableCameras();
      controller = CameraController(cameras[0], ResolutionPreset.medium);
      await controller.initialize();
      await loadYoloModel();
      setState(() {
        isLoaded = true;
        isDetecting = false;
      });
      setupFrameProcessing();
    } catch (e) {
      debugPrint("Error during initialization: $e");
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

    /// Increase the number of threads if you have a powerful device. You can use the [getOptimalThreadCount] method
    /// implementation from [camera_app.dart] to get the optimal number of threads for the device.
    /// Also you can set the [useGpu] to true if the device can open a GPU delegate.
    /// You can also set the [quantization] to false if you want the model to be more accurate in its detection. But this
    /// might decrease the performance speed.
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

    /// lower the value of the thresholds, [confThreshold], [iouThreshold] and [classThreshold] if you want to increase the number of vehicles detected. But this might decrease the performance speed as well as the accuracy of the detection.
    /// Increase the values of the thresholds if you want to display the vehicles with higher confidence. But this will decrease the number of vehicles detected, resulting in an increase in false negatives.
    return result;
  }

  /// The [sendFrameToWebSocket] function is used to send the frame to the server's socket.
  /// To send the frame to the server,
  /// 1, we only want to send the cropped images of the vehicles detected on the frame.
  /// 2, the cropped images have to be encoded in base64 format.
  /// 3, format to send the data to the server is a json of the form {"data": ["list of base64_encoded_images of the cropped vehicles detected on the frame"]}
  Future<void> sendFrameToWebSocket(
      CameraImage frame, List<Map<String, dynamic>> detections) async {
    if (!_isSocketConnected) return;

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
      // crop the image from the frame and convert it to a jpeg image then encode it to base64
      final img.Image convertedImage = convertToImage(frame, cropBox);
      Uint8List imageData = Uint8List.fromList(img.encodeJpg(convertedImage));
      String base64Image = base64Encode(imageData);
      imageStrings.add(base64Image);
    }

    if (imageStrings.isNotEmpty) {
      _webSocketManager.send(jsonEncode({'data': imageStrings}));
      setState(() {
        listOfRecognitionCrops.add(cropBoxes);
        // add the crop boxes to the list of crop boxes to later be used to draw the boxes on the screen
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSocketConnected && _webSocketManager.state == SocketState.error) {
      return Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return MainApp(cameras: widget.cameras);
            }));
          },
          backgroundColor: Colors.white,
          child: const Icon(Icons.arrow_back_ios),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Connecting to server..."),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    final Size size = MediaQuery.of(context).size;
    if (!isLoaded) {
      return Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return MainApp(cameras: widget.cameras);
            }));
          },
          backgroundColor: Colors.white,
          child: const Icon(Icons.arrow_back_ios),
        ),
        body: const Center(
          child: Text("Model not loaded, waiting for it"),
        ),
      );
    }
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return MainApp(cameras: widget.cameras);
          }));
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.arrow_back_ios),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
          ...displayBoxesAroundVehicles(size),
          ...displayBoxesAroundPlates(size),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: toggleDetection,
                        child: Icon(
                          isDetecting ? Icons.stop : Icons.play_arrow,
                          color: isDetecting ? Colors.red : Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDetecting ? "Stop" : "Start",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

    /// start the image stream from the camera and process the frames at a rate of [targetFPS]
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
    _webSocketManager.dispose();
    // if (socketHasNoErrors) {
    //   _channel.sink.close();
    // }
    super.dispose();
  }

  /// The [displayBoxesAroundPlates] method displays the boxes around the detected plates on the screen along with their
  /// plate number uses the [listOfRecognitionCrops] to draw the boxes around the detected plates. It draws the boxes by
  /// picking the first crop box from the [listOfRecognitionCrops] and then drawing the boxes around the detected plates.
  List<Widget> displayBoxesAroundPlates(Size screen) {
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

        String plateNumber = results.plateNumbers[idx];

        // position calculations
        double boxWidth = (result[2] - result[0]) * factorX;
        double boxHeight = (result[3] - result[1]) * factorY;
        bool isBoxTooSmall = boxWidth < 30 || boxHeight < 20;

        // use crop boxes prior to vehicle detection to update values
        double leftPosition = (result[0] + cropBox[0]) * factorX;
        double topPosition = (result[1] + cropBox[1]) * factorY;

        idx++;
        // Increment index after accessing the [PlateNumber] from [plateNumbers]

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
                            "$plateNumber ",

                            /// "${(results.boxConfs[idx - 1] * 100).toStringAsFixed(0)}%" You can use this to display the confidence of the license plate detection
                            /// This confidence is not the confidence of the plate number recognition but the confidence of the license plate detection
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

  /// The [convertToImage] method converts the [CameraImage] to an [Image] object.
  /// The [cropBox] is used to crop the the vehicles detected from the frame before converting it to an [Image] object.
  img.Image convertToImage(CameraImage frame, List<int>? cropBox) {
    final int width = frame.width;
    final int height = frame.height;
    final img.Image imgImage = img.Image(width, height);

    if (frame.format.group == ImageFormatGroup.yuv420) {
      final Plane planeY = frame.planes[0];
      final Plane planeU = frame.planes[1];
      final Plane planeV = frame.planes[2];

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

    /// I had to rotate the image by 90 degrees clockwise. I don't know why but it works.
    /// It might be because the orientation of the camera but if I didn't rotate the image by 90 degrees clockwise, the
    /// server wouldn't give the correct boxes, even though the server would still sending the right license plates.
    img.Image rotatedImage = img.copyRotate(imgImage, 90);

    // Crop the image by the [cropBox]
    if (cropBox != null) {
      int x = cropBox[0];
      int y = cropBox[1];
      int w = cropBox[2];
      int h = cropBox[3];

      rotatedImage = img.copyCrop(rotatedImage, x, y, w, h);
    }

    return rotatedImage;
  }
}
