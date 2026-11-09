import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Centralized utility for showing application SnackBars / popups.
/// Ensures all popups reliably auto-dismiss after [duration] (default 5 seconds),
/// clears previous queued popups, provides a fallback timer so popups
/// never get stuck even if route transitions occur while visible, and styles
/// positive responses in green and errors/unexpected behaviors in red.
class AppSnackBar {
  const AppSnackBar._();

  /// Default duration for all popups across the app: 5 seconds.
  static const Duration defaultDuration = Duration(seconds: 5);

  /// Green background color for positive/success feedback.
  static const Color successColor = Color(0xFF16A34A);

  /// Red background color for errors and unexpected behavior.
  static const Color errorColor = Color(0xFFDC2626);

  /// Shows a [SnackBar] with guaranteed 5-second auto-dismissal.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    BuildContext context,
    SnackBar snackBar, {
    Duration duration = defaultDuration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return null;

    // Immediately remove previous snackbar so they don't pile up or get queued
    messenger.removeCurrentSnackBar();

    final effectiveSnackBar = SnackBar(
      key: snackBar.key,
      content: snackBar.content,
      backgroundColor: snackBar.backgroundColor,
      elevation: snackBar.elevation ?? 6.0,
      margin: snackBar.margin,
      padding: snackBar.padding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      width: snackBar.width,
      shape: snackBar.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hitTestBehavior: snackBar.hitTestBehavior,
      behavior: snackBar.behavior ?? SnackBarBehavior.floating,
      action: snackBar.action,
      actionOverflowThreshold: snackBar.actionOverflowThreshold,
      showCloseIcon: snackBar.showCloseIcon,
      closeIconColor: snackBar.closeIconColor,
      duration: duration,
      animation: snackBar.animation,
      onVisible: snackBar.onVisible,
      dismissDirection: snackBar.dismissDirection ?? DismissDirection.down,
      clipBehavior: snackBar.clipBehavior,
    );

    final controller = messenger.showSnackBar(effectiveSnackBar);

    // Guaranteed fallback timer: if route changes freeze Flutter's internal timer,
    // this ensures the popup closes cleanly after the specified duration.
    // In widget test environments, ScaffoldMessenger manages dismissal timers cleanly.
    final isTestEnvironment =
        Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTestEnvironment) {
      Timer? fallbackTimer;
      fallbackTimer = Timer(duration + const Duration(milliseconds: 150), () {
        try {
          controller.close();
        } catch (_) {}
      });

      controller.closed.whenComplete(() {
        fallbackTimer?.cancel();
      });
    }

    return controller;
  }

  /// Green floating SnackBar with a checkmark icon for positive responses and confirmations.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showSuccess(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = defaultDuration,
  }) {
    return show(
      context,
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.circleCheck,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: action,
        duration: duration,
      ),
      duration: duration,
    );
  }

  /// Red floating SnackBar with an alert icon for errors or unexpected behavior.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = defaultDuration,
  }) {
    return show(
      context,
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.alertCircle,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: action,
        duration: duration,
      ),
      duration: duration,
    );
  }

  /// Convenience helper to show a text message with guaranteed 5-second dismissal.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showMessage(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    SnackBarAction? action,
    Duration duration = defaultDuration,
  }) {
    return show(
      context,
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        backgroundColor: backgroundColor ?? const Color(0xFF1F2937),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: action,
        duration: duration,
      ),
      duration: duration,
    );
  }
}
