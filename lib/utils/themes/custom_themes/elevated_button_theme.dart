import 'package:flutter/material.dart';
import 'package:demo_app/utils/constants/values.dart';

class CustomElevatedButtonTheme {
  CustomElevatedButtonTheme._();

  /// -- Light Theme
  static final lightElevatedButtonTheme = ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
    elevation: 0,
    foregroundColor: Colors.white,
    backgroundColor: primaryColor,
    disabledForegroundColor: Colors.grey,
    // disabledBackgroundColor: Colors.grey,
    disabledBackgroundColor: primaryColorLight3,
    side: const BorderSide(color: primaryColor),
    padding: const EdgeInsets.symmetric(vertical: 18),
    textStyle: const TextStyle(
        fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));

  /// -- Dark Theme
  static final darkElevatedButtonTheme = ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
    elevation: 0,
    foregroundColor: Colors.white,
    backgroundColor: primaryColor,
    disabledForegroundColor: Colors.grey,
    // disabledBackgroundColor: Colors.grey,
    disabledBackgroundColor: primaryColorLight3,
    side: const BorderSide(color: primaryColor),
    padding: const EdgeInsets.symmetric(vertical: 18),
    textStyle: const TextStyle(
        fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}
