import 'package:flutter/material.dart';

import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';

/// The shared text field look: `field` fill, radius 14, 52 high, an optional
/// leading icon, an accent focus ring and a danger error border.
///
/// This only restyles presentation — pass through the same controller,
/// validator, obscure-toggle and callbacks the screen already uses.
class InkTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final IconData? leadingIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final AutovalidateMode? autovalidateMode;

  const InkTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.errorText,
    this.leadingIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      autofocus: autofocus,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      focusNode: focusNode,
      autovalidateMode: autovalidateMode,
      style: InkType.body(tokens.ink),
      cursorColor: tokens.accent,
      decoration: InputDecoration(
        isDense: false,
        hintText: hintText,
        labelText: labelText,
        errorText: errorText,
        hintStyle: InkType.body(tokens.inkMuted),
        labelStyle: InkType.body(tokens.inkMuted),
        filled: true,
        fillColor: tokens.field,
        constraints: const BoxConstraints(minHeight: 52),
        contentPadding: EdgeInsets.symmetric(
          horizontal: InkSpacing.s16,
          vertical: maxLines > 1 ? InkSpacing.s16 : 15,
        ),
        prefixIcon: leadingIcon != null
            ? Icon(leadingIcon, size: 20, color: tokens.inkSecondary)
            : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkRadii.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkRadii.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkRadii.input),
          borderSide: BorderSide(color: tokens.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkRadii.input),
          borderSide: BorderSide(color: tokens.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkRadii.input),
          borderSide: BorderSide(color: tokens.danger, width: 1.5),
        ),
      ),
    );
  }
}
