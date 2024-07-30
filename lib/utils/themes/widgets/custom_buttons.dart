import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:demo_app/utils/constants/values.dart';

class CustomFullWidthButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  const CustomFullWidthButton(
      {super.key, required this.onPressed, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        color: primaryColor,
      ),
      width: MediaQuery.of(context).size.width * .9,
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          text,
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
      ),
    );
  }
}
