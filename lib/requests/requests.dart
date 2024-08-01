import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// final urlToUploadImage = Uri.parse('https://10.0.2.2/predict_image');

// final urlToUploadImage = Uri.parse('http://127.0.0.1:8000/identify_svm');
final base = 'https://81b6-196-190-62-161.ngrok-free.app';

Future<Map<String, dynamic>> uploadImage(File image) async {
  var url = Uri.parse(base + '/file-read-plate/');
  var request = http.MultipartRequest('POST', url);
  var file = await http.MultipartFile.fromPath('file', image.path);
  request.files.add(file);

  try {
    var response = await request.send();
    // var response = await http.Response.fromStream(streamedResponse);
    debugPrint("Response status code: ${response.statusCode}");
    if (response.statusCode == 200) {
      var responseBody = await response.stream.bytesToString();
      var responseData = jsonDecode(responseBody);
      debugPrint("Response data: $responseData");
      return {};
      // List<dynamic> jsonResponse = json.decode(response.body);
      // // var result = jsonResponse.cast<Map<String, dynamic>>();
      // debugPrint("Response body: $jsonResponse");
      // return {};
    } else {
      throw Exception(
          'Failed to detect objects. Status code: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error occurred while making the request: $e');
  }
}


//   try {
//     var response = await request.send();
//     debugPrint("Response status code: ${response.statusCode}");

//     if (response.statusCode == 200) {
//       var responseBody = await response.stream.bytesToString();
//       var responseData = jsonDecode(responseBody);
//       debugPrint("Response data: $responseData");
//       return {};
//     } else {
//       print('Error: ${response.statusCode}');
//       return {};
//     }
//   } catch (e) {
//     print('Error: $e');
//     return {};
//   }