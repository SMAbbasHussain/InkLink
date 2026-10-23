import 'package:flutter/material.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_text_field.dart';

class ProfileEditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final int maxLines;

  const ProfileEditField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: InkType.label(tokens.inkMuted)),
        const SizedBox(height: InkSpacing.s8),
        InkTextField(
          controller: controller,
          maxLines: maxLines,
          leadingIcon: icon,
        ),
      ],
    );
  }
}
