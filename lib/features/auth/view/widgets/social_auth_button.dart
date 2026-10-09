import 'package:flutter/material.dart';

import '../../../../ui/widgets/ink_button.dart';

class SocialAuthButton extends StatelessWidget {
  final String text;
  final String iconUrl;
  final VoidCallback onTap;

  const SocialAuthButton({
    super.key,
    required this.text,
    required this.iconUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkButton.secondary(
      label: text,
      onPressed: onTap,
      icon: Image.network(iconUrl, height: 20, width: 20),
    );
  }
}
