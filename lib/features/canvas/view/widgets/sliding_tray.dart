import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';

enum TrayDirection { left, right, top, bottom }

class SlidingTray extends StatefulWidget {
  final bool isOpen;
  final TrayDirection direction;
  final Widget child;
  final double width;
  final double height;
  final String title;
  final Widget? headerActions;
  final double? topOffset;
  final double? bottomOffset;
  final VoidCallback? onClose;

  const SlidingTray({
    super.key,
    required this.isOpen,
    required this.direction,
    required this.child,
    this.width = 250,
    this.height = 300,
    required this.title,
    this.headerActions,
    this.topOffset,
    this.bottomOffset,
    this.onClose,
  });

  /// Browser window wide enough for the desktop tray layout.
  static bool useWebLayout(BuildContext context) =>
      (debugWebLayoutOverride ?? kIsWeb) &&
      MediaQuery.sizeOf(context).width >= _webMinWidth;

  /// Tests only: pretend to run (or not) in a browser. Null in the app.
  @visibleForTesting
  static bool? debugWebLayoutOverride;

  static const double _webMinWidth = 700;

  @override
  State<SlidingTray> createState() => _SlidingTrayState();
}

class _SlidingTrayState extends State<SlidingTray> {
  bool _isAnimating = false;

  @override
  void didUpdateWidget(covariant SlidingTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      _isAnimating = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (SlidingTray.useWebLayout(context)) return _buildWeb(context);

    final tokens = context.ink;
    final isOpen = widget.isOpen;
    final direction = widget.direction;
    final width = widget.width;
    final height = widget.height;
    final topOffset = widget.topOffset;
    final bottomOffset = widget.bottomOffset;
    final onClose = widget.onClose;
    final isActive = isOpen || _isAnimating;

    // Calculate off-screen positions
    double? top, bottom, left, right;
    const inset = 12.0;

    switch (direction) {
      case TrayDirection.left:
        left = isOpen ? inset : -width - 20; // Extra offset for shadow
        top = topOffset ?? (bottomOffset == null ? 100.0 : null);
        bottom = bottomOffset;
        break;
      case TrayDirection.right:
        right = isOpen ? inset : -width - 20;
        top = topOffset ?? (bottomOffset == null ? 100.0 : null);
        bottom = bottomOffset;
        break;
      case TrayDirection.top:
        top = isOpen ? inset : -height - 20;
        left = MediaQuery.of(context).size.width / 2 - (width / 2);
        break;
      case TrayDirection.bottom:
        bottom = isOpen ? inset : -height - 20;
        left = inset;
        right = inset;
        break;
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      onEnd: () {
        if (_isAnimating && mounted) {
          setState(() => _isAnimating = false);
        }
      },
      child: Offstage(
        offstage: !isActive,
        child: TickerMode(
          enabled: isActive,
          child: IgnorePointer(
            ignoring: !isOpen,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) {
                if (direction == TrayDirection.left && d.delta.dx < -8) {
                  HapticFeedback.lightImpact();
                  onClose?.call();
                } else if (direction == TrayDirection.right && d.delta.dx > 8) {
                  HapticFeedback.lightImpact();
                  onClose?.call();
                }
              },
              onVerticalDragUpdate: (d) {
                if (direction == TrayDirection.bottom && d.delta.dy > 8) {
                  HapticFeedback.lightImpact();
                  onClose?.call();
                } else if (direction == TrayDirection.top && d.delta.dy < -8) {
                  HapticFeedback.lightImpact();
                  onClose?.call();
                }
              },
              child: SizedBox(
                width: width,
                height: height,
                child: GlassPanel(
                  radius: InkRadii.glassBar,
                  child: Column(
                    children: [
                      // Header Handle (UX cue for swiping)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (d) {
                          if (direction == TrayDirection.bottom &&
                              d.delta.dy > 6) {
                            onClose?.call();
                          } else if (direction == TrayDirection.top &&
                              d.delta.dy < -6) {
                            onClose?.call();
                          }
                        },
                        onHorizontalDragUpdate: (d) {
                          if (direction == TrayDirection.left &&
                              d.delta.dx < -6) {
                            onClose?.call();
                          } else if (direction == TrayDirection.right &&
                              d.delta.dx > 6) {
                            onClose?.call();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: tokens.inkMuted.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: InkSpacing.s8,
                          horizontal: InkSpacing.s16,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: InkType.bodyStrong(tokens.ink),
                              ),
                            ),
                            ?widget.headerActions,
                            if (onClose != null) ...[
                              const SizedBox(width: InkSpacing.s8),
                              InkWell(
                                borderRadius: BorderRadius.circular(
                                  InkRadii.chip,
                                ),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  onClose.call();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    LucideIcons.x,
                                    size: 18,
                                    color: tokens.inkSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Divider(height: 1, color: tokens.glassStroke),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Web (desktop browser) layout ─────────────────────────────────────
  //
  // Phones never reach this: it only runs on the web in a window at least
  // [_webMinWidth] wide. Trays become compact floating panels that never
  // cover the whole canvas: bottom trays (Brush & Color) dock on the left
  // under the top bar at a fixed width instead of spanning the screen, and every
  // tray is capped to the visible height so its content scrolls inside.
  // There is no swipe handle (mouse users close with the X).

  static const double _webEdge = 16;

  /// Left trays open beside the board's tool rail, not over it.
  static const double _webLeftEdge = 84;
  static const double _webTopBar = 76; // clears the board's top bar
  static const double _webToolbar = 84; // clears the bottom toolbar
  static const double _webBottomTrayWidth = 320;

  Widget _buildWeb(BuildContext context) {
    final tokens = context.ink;
    final screen = MediaQuery.sizeOf(context);
    // The widget's settings, read the same way as the phone build above.
    final isOpen = widget.isOpen;
    final direction = widget.direction;
    final width = widget.width;
    final height = widget.height;
    final topOffset = widget.topOffset;
    final bottomOffset = widget.bottomOffset;
    final onClose = widget.onClose;
    final title = widget.title;
    final headerActions = widget.headerActions;
    final child = widget.child;

    double? top, bottom, left, right;
    var trayWidth = width;
    double maxHeight;

    switch (direction) {
      case TrayDirection.left:
      case TrayDirection.right:
        final topEdge = topOffset ?? (bottomOffset == null ? 100.0 : null);
        top = topEdge;
        bottom = bottomOffset;
        maxHeight =
            screen.height -
            (topEdge ?? _webTopBar) -
            (bottomOffset ?? _webToolbar);
        final hidden = -trayWidth - 24;
        if (direction == TrayDirection.left) {
          left = isOpen ? _webLeftEdge : hidden;
        } else {
          right = isOpen ? _webEdge : hidden;
        }
        break;
      case TrayDirection.top:
        trayWidth = width.clamp(0, screen.width - 2 * _webEdge).toDouble();
        maxHeight = screen.height - _webTopBar - _webToolbar;
        top = isOpen ? _webTopBar : -height - 24;
        left = (screen.width - trayWidth) / 2;
        break;
      case TrayDirection.bottom:
        // Docked on the left under the top bar (like a properties panel),
        // clear of the centred toolbar, so the middle of the board stays
        // visible while drawing.
        trayWidth = _webBottomTrayWidth
            .clamp(0, screen.width - 2 * _webEdge)
            .toDouble();
        maxHeight = screen.height - _webTopBar - _webEdge;
        top = _webTopBar;
        left = isOpen ? _webLeftEdge : -trayWidth - 24;
        break;
    }
    // The tray's own height, but never taller than the visible space.
    final trayHeight = math.min(height, math.max(160.0, maxHeight));

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        ignoring: !isOpen,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isOpen ? 1 : 0,
          child: SizedBox(
            width: trayWidth,
            height: trayHeight,
            child: GlassPanel(
              radius: InkRadii.glassBar,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      InkSpacing.s16,
                      InkSpacing.s12,
                      InkSpacing.s8,
                      InkSpacing.s8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: InkType.bodyStrong(tokens.ink),
                          ),
                        ),
                        ?headerActions,
                        if (onClose != null)
                          IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            splashRadius: 16,
                            onPressed: onClose,
                            icon: Icon(
                              LucideIcons.x,
                              size: 16,
                              color: tokens.inkSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: tokens.glassStroke),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
