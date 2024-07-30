import 'dart:io';
import 'package:demo_app/service/detection_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final base = 'https://bc15-169-150-218-58.ngrok-free.app';

class DetectionService {
  static Future<DetectionResult> detectAndOcr(File imageFile) async {
    var uri = Uri.parse('$base/detect/ocr/');
    var request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonResult = json.decode(responseData);
      return DetectionResult.fromJson(jsonResult);
    } else {
      throw Exception('Failed to detect and OCR');
    }
  }
}
