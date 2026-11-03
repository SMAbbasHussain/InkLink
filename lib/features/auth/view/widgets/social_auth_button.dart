import 'package:flutter/material.dart';

import '../../../../ui/widgets/ink_button.dart';

class SocialAuthButton extends StatelessWidget {
  final String text;
  final String? iconUrl;
  final String? assetPath;
  final VoidCallback onTap;

  const SocialAuthButton({
    super.key,
    required this.text,
    this.iconUrl,
    this.assetPath,
    required this.onTap,
  });

  Widget _buildIcon() {
    if (assetPath != null && assetPath!.isNotEmpty) {
      return Image.asset(
        assetPath!,
        height: 20,
        width: 20,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.g_mobiledata, size: 20),
      );
    }
    if (iconUrl != null && iconUrl!.isNotEmpty) {
      return Image.network(
        iconUrl!,
        height: 20,
        width: 20,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.g_mobiledata, size: 20),
      );
    }
    return const Icon(Icons.login, size: 20);
  }

  @override
  Widget build(BuildContext context) {
    return InkButton.secondary(
      label: text,
      onPressed: onTap,
      icon: _buildIcon(),
    );
  }
}
