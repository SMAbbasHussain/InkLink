import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_button.dart';

class TrayTipsOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const TrayTipsOverlay({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Stack(
            children: [
              // TOP LEFT: Members & Chat
              Align(
                alignment: Alignment.topLeft,
                child: _tipPill(
                  icon: LucideIcons.users,
                  title: 'Members & Chat',
                  subtitle: 'Swipe right or tap tab',
                  margin: const EdgeInsets.only(left: 16, top: 72),
                ),
              ),

              // TOP RIGHT: AI Assistant
              Align(
                alignment: Alignment.topRight,
                child: _tipPill(
                  icon: LucideIcons.sparkles,
                  title: 'AI Assistant',
                  subtitle: 'Swipe left or tap tab',
                  margin: const EdgeInsets.only(right: 16, top: 72),
                ),
              ),

              // BOTTOM LEFT: Board & History
              Align(
                alignment: Alignment.bottomLeft,
                child: _tipPill(
                  icon: LucideIcons.slidersHorizontal,
                  title: 'Board & History',
                  subtitle: 'Swipe right or tap tab',
                  margin: const EdgeInsets.only(left: 16, bottom: 176),
                ),
              ),

              // BOTTOM RIGHT: Canvas Tools
              Align(
                alignment: Alignment.bottomRight,
                child: _tipPill(
                  icon: LucideIcons.layoutGrid,
                  title: 'Canvas Tools',
                  subtitle: 'Swipe left or tap tab',
                  margin: const EdgeInsets.only(right: 16, bottom: 176),
                ),
              ),

              // BOTTOM CENTER: Quick Access Bar
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 72, left: 16, right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.panelBottom,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Quick Access Bar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  LucideIcons.arrowDown,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap Pen for brush & color • Tap ••• to customize bottom bar',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // CENTER: Main explainer card
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Canvas Gestures & Trays',
                          style: InkType.headline(Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Swipe inward from screen edges or tap side tabs to open trays.\nUse the bottom Quick Access Bar for instant drawing tools.\nYou can toggle this helper in Settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // BOTTOM RIGHT: Got it button
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 12),
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

  Widget _tipPill({
    required IconData icon,
    required String title,
    required String subtitle,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
