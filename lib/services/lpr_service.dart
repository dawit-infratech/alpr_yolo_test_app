import 'dart:io';
import 'package:demo_app/services/models/lpr_result.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// TODO: change to server url
final base = 'http://localhost:8000';

class LPRService {
  static Future<LPRResult> detectAndReadFromFile(File imageFile) async {
    var uri = Uri.parse('$base/file-read-plate/');
    var request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonResult = json.decode(responseData);
      debugPrint("responseData: $responseData");
      return LPRResult.fromJson(jsonResult);
    } else {
      throw Exception('Failed to detect and OCR');
    }
  }
}
