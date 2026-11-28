import 'package:flutter/material.dart';

/// Sections of the signed-in web companion, in sidebar order.
enum WebSection {
  boards,
  workspaces,
  discover,
  invites,
  friends,
  notifications,
  profile,
  settings,
}

/// Lets a page jump to another section (e.g. the waiting-invites banner).
class WebShellNav extends InheritedWidget {
  final ValueChanged<WebSection> goTo;

  const WebShellNav({super.key, required this.goTo, required super.child});

  static WebShellNav? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WebShellNav>();

  @override
  bool updateShouldNotify(WebShellNav oldWidget) => goTo != oldWidget.goTo;
}

/// From this width up the web companion uses the desktop sidebar layout;
/// below it, the floating glass nav bar.
const double webSidebarMinWidth = 900;

/// Bottom content padding: compact on desktop, room for the floating bar on
/// narrow windows.
double webPageBottomPadding(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= webSidebarMinWidth ? 32 : 110;
