// import 'package:flutter/material.dart';
// import 'package:intl_phone_number_input/intl_phone_number_input.dart';

// class BuildPhoneNumberField extends StatefulWidget {
//   final String labelText;
//   final Icon? icon;
//   final String hintText;
//   final bool obscured;
//   final TextEditingController controller;
//   final bool readOnly;
//   final Function(String) onChanged;
//   final Function(String) onSaved;
//   final String? initialCountry;

//   const BuildPhoneNumberField({
//     Key? key,
//     required this.controller,
//     required this.labelText,
//     required this.hintText,
//     this.icon,
//     this.obscured = false,
//     this.readOnly = false,
//     required this.onChanged,
//     required this.onSaved,
//     this.initialCountry,
//   }) : super(key: key);

//   @override
//   State<BuildPhoneNumberField> createState() => _BuildPhoneNumberFieldState();
// }

// class _BuildPhoneNumberFieldState extends State<BuildPhoneNumberField> {
//   String? phoneNumber;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 25),
//       child: Container(
//         height: 42,
//         decoration: const BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.all(Radius.circular(20))),
//         child: InternationalPhoneNumberInput(
//           onInputChanged: (PhoneNumber number) {
//             widget.onChanged(number.phoneNumber ?? '');
//             setState(() {
//               phoneNumber = number.phoneNumber;
//             });
//           },
//           onInputValidated: (bool value) {
//             // validation here
//           },
//           selectorConfig: const SelectorConfig(
//             selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
//           ),
//           ignoreBlank: false,
//           autoValidateMode: AutovalidateMode.disabled,
//           selectorTextStyle: const TextStyle(color: Colors.black),
//           initialValue: PhoneNumber(isoCode: widget.initialCountry ?? 'US'),
//           textFieldController: widget.controller,
//           // textFieldDecoration: InputDecoration(
//           //   labelText: widget.labelText,
//           //   hintText: widget.hintText,
//           //   hintStyle: const TextStyle(fontWeight: FontWeight.w400),
//           //   prefixIcon: widget.icon,
//           //   border: OutlineInputBorder(
//           //     borderRadius: BorderRadius.circular(14.0),
//           //   ),
//           // ),
//         ),
//       ),
//     );
//   }
// }
