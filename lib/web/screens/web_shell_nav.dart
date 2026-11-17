import 'package:flutter/widgets.dart';

/// Sections of the signed-in web companion, in sidebar order.
enum WebSection { boards, discover, invites, friends, notifications, profile }

/// Lets a page jump to another section (e.g. the "2 invites waiting" chip).
class WebShellNav extends InheritedWidget {
  final ValueChanged<WebSection> goTo;

  const WebShellNav({super.key, required this.goTo, required super.child});

  static WebShellNav? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WebShellNav>();

  @override
  bool updateShouldNotify(WebShellNav oldWidget) => goTo != oldWidget.goTo;
}
