import 'package:flutter/material.dart';

import '../../../../ui/widgets/ink_text_field.dart';

class AuthTextField extends StatefulWidget {
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextEditingController? controller;

  const AuthTextField({
    super.key,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    this.controller,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  @override
  Widget build(BuildContext context) {
    return InkTextField(
      controller: widget.controller,
      hintText: widget.hintText,
      leadingIcon: widget.icon,
      obscureText: widget.isPassword,
    );
  }
}
