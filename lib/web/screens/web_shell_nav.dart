import 'package:flutter/material.dart';

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

/// From this width the web companion uses the desktop layout (top bar and
/// sidebar); below it, the phone's floating nav bar.
const double webSidebarMinWidth = 900;

/// Space to leave under a page's content: little on desktop, room for the
/// floating nav bar on small windows.
double webPageBottomPadding(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= webSidebarMinWidth ? 32 : 110;
