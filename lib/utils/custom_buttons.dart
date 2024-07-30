import 'package:flutter/material.dart';

class CustomButtons {
  static ElevatedButton customButton(String buttonText, Function onPressed) {
    return ElevatedButton(
      style: ButtonStyle(
        backgroundColor:
            MaterialStateProperty.all<Color>(Colors.purple.shade900),
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
            side: const BorderSide(color: Colors.white),
          ),
        ),
        padding: MaterialStateProperty.all<EdgeInsets>(
          const EdgeInsets.symmetric(horizontal: 100.0, vertical: 20.0),
        ),
        textStyle: MaterialStateProperty.all<TextStyle>(
          const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
        ),
      ),
      onPressed: () {
        onPressed();
      },
      child: Text(buttonText),
    );
  }
}
