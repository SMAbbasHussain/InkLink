// Entry point for the InkLink WEB COMPANION.
//
//   flutter run -d chrome -t lib/web/main_web.dart
//   flutter build web --release -t lib/web/main_web.dart
//
// This is separate from the mobile app (lib/main.dart). It reuses the
// web-safe parts of the codebase (Firebase wrappers, models, Ink design
// system) and the mobile canvas with web services (lib/web/canvas/). It never
// imports the mobile app's Isar database, so nothing here changes how the
// phone app works.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../firebase_options.dart';
import 'canvas/web_canvas.dart';
import 'web_companion_app.dart';
import 'widgets/web_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter web keeps the accessibility tree off until something asks for it,
  // so screen readers and keyboard users only see "Enable accessibility".
  // Turn it on from the start so every field, button and label is readable.
  SemanticsBinding.instance.ensureSemantics();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final canvas = await WebCanvasServices.create();
  runApp(
    WebCompanionApp(
      boardOpener: WebBoardOpener(
        (context, board) => Navigator.of(
          context,
        ).push(buildWebCanvasRoute(canvas, boardId: board.id)),
      ),
    ),
  );
}
