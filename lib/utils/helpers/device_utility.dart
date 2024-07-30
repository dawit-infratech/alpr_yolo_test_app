import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DeviceUtils {
  DeviceUtils._();

  static double getAppBarHeight() {
    return kToolbarHeight;
  }

  static double getStatusBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  static double getStatusBarHeightWithSafeArea(BuildContext context) {
    return MediaQuery.of(context).padding.top +
        MediaQuery.of(context).padding.bottom;
  }

  static double getStatusBarHeightWithBottomSafeArea(BuildContext context) {
    return MediaQuery.of(context).padding.top +
        MediaQuery.of(context).padding.bottom +
        MediaQuery.of(context).padding.bottom;
  }

  static double getPixelRatio(BuildContext context) {
    return MediaQuery.of(context).devicePixelRatio;
  }

  static double getBottomNavigationBarHeight() {
    return kBottomNavigationBarHeight;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double getKeyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  static Future<bool> isKeyboardVisible(BuildContext context) async {
    final viewInsets = View.of(context).viewInsets;
    return viewInsets.bottom > 0;
  }

  static Future<bool> isPhysicalDevice() async {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static void vibrate(Duration duration) {}
}
