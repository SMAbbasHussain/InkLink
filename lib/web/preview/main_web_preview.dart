// DESIGN PREVIEW of the web companion, with sample data. No Firebase, no
// account, nothing real is read or written. For designers and developers:
//
//   flutter run -d chrome -t lib/web/preview/main_web_preview.dart
//
// Add  ?signedOut  to the URL to start on the sign-in screen (any password of
// 6+ characters signs in), ?dark or ?light to force a theme, and
// ?section=discover|invites|friends|notifications|profile to open a page.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../screens/web_shell_nav.dart';
import '../web_companion_app.dart';
import 'sample_web_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final query = Uri.base.queryParameters;
  final section = WebSection.values
      .where((s) => s.name == query['section'])
      .firstOrNull;
  runApp(WebCompanionApp(
    initialSection: section ?? WebSection.boards,
    repository: SampleWebCompanionRepository(
      signedIn: !query.containsKey('signedOut'),
    ),
    themeMode: query.containsKey('dark')
        ? ThemeMode.dark
        : query.containsKey('light')
            ? ThemeMode.light
            : ThemeMode.system,
  ));
}
