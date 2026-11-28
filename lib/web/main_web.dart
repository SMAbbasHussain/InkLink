// Entry point for the InkLink WEB COMPANION.
//
//   flutter run -d chrome -t lib/web/main_web.dart
//   flutter build web --release -t lib/web/main_web.dart
//
// This is separate from the mobile app (lib/main.dart). All bootstrap and
// web dependency composition lives in lib/app/composition/web_dependencies.dart
// and shares core canvas wiring through SharedCanvasDependencies without ever
// importing mobile-only packages (Isar, path_provider, Agora).

import 'package:flutter/material.dart';

import '../app/composition/web_dependencies.dart';
import 'canvas/web_canvas.dart';
import 'web_companion_app.dart';
import 'widgets/web_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await WebDependencies.bootstrap();

  runApp(
    WebCompanionApp(
      repository: dependencies.companionRepository,
      initialSection: dependencies.initialSection,
      initialBoardId: dependencies.initialBoardId,
      boardOpener: WebBoardOpener(
        (context, board) => Navigator.of(context).push(
          buildWebCanvasRoute(dependencies.canvasServices, boardId: board.id),
        ),
        openId: (context, boardId) => Navigator.of(context).push(
          buildWebCanvasRoute(dependencies.canvasServices, boardId: boardId),
        ),
      ),
    ),
  );
}
