import 'package:flutter/material.dart';

import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_button.dart';

class TrayTipsOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const TrayTipsOverlay({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: _tipPill(
                  'Swipe right\nMembers',
                  margin: const EdgeInsets.only(left: 16, top: 72),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: _tipPill(
                  'Swipe left\nAI',
                  margin: const EdgeInsets.only(right: 16, top: 72),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: _tipPill(
                  'Swipe right\nTools',
                  margin: const EdgeInsets.only(left: 16, bottom: 120),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: _tipPill(
                  'Swipe left\nShapes',
                  margin: const EdgeInsets.only(right: 16, bottom: 120),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _tipPill(
                  'Swipe up\nBrushes',
                  margin: const EdgeInsets.only(bottom: 48),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Canvas Gestures',
                        style: InkType.headline(Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Use edge swipes to open trays. You can disable this helper in Settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 8),
                  child: InkButton.hero(
                    label: 'Got it',
                    expand: false,
                    compact: true,
                    onPressed: onDismiss,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipPill(String text, {EdgeInsets margin = EdgeInsets.zero}) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}
