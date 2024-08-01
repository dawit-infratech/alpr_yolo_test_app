import 'dart:io';
import 'package:demo_app/service/detection_result.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final base = 'https://81b6-196-190-62-161.ngrok-free.app';

class DetectionService {
  static Future<DetectionResult> detectAndOcr(File imageFile) async {
    var uri = Uri.parse('$base/file-read-plate/');
    var request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonResult = json.decode(responseData);
      debugPrint("responseData: $responseData");
      return DetectionResult.fromJson(jsonResult);
    } else {
      throw Exception('Failed to detect and OCR');
    }
  }
}
