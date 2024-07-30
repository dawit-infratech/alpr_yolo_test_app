import 'package:demo_app/utils/constants/values.dart';
import 'package:flutter/material.dart';

import 'custom_themes/custom_themes.dart';

class CustomTheme {
  CustomTheme._();

  static ThemeData lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
      // colorScheme: const ColorScheme.light(),
      useMaterial3: true,
      // fontFamily: 'Poppins',
      brightness: Brightness.light,
      textTheme: CustomTextTheme.lightTextTheme,
      appBarTheme: CustomAppBarTheme.lightAppBarTheme,
      checkboxTheme: CustomCheckboxTheme.lightCheckboxTheme,
      bottomSheetTheme: CustomBottomSheetTheme.lightBottomSheetTheme,
      elevatedButtonTheme: CustomElevatedButtonTheme.lightElevatedButtonTheme,
      chipTheme: CustomChipTheme.lightChipTheme,
      outlinedButtonTheme: CustomOutlinedButtonTheme.lightOutlinedButtonTheme,
      inputDecorationTheme: CustomTextFieldTheme.lightInputDecorationTheme);

  static ThemeData darkTheme = ThemeData(
      // colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
      colorScheme: const ColorScheme.dark(),
      useMaterial3: true,
      // fontFamily: 'Poppins',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.grey.shade900,
      textTheme: CustomTextTheme.darkTextTheme,
      appBarTheme: CustomAppBarTheme.darkAppBarTheme,
      checkboxTheme: CustomCheckboxTheme.darkCheckboxTheme,
      bottomSheetTheme: CustomBottomSheetTheme.darkBottomSheetTheme,
      elevatedButtonTheme: CustomElevatedButtonTheme.darkElevatedButtonTheme,
      chipTheme: CustomChipTheme.darkChipTheme,
      outlinedButtonTheme: CustomOutlinedButtonTheme.darkOutlinedButtonTheme,
      inputDecorationTheme: CustomTextFieldTheme.darkInputDecorationTheme);
}
