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
import 'features/canvas/view/web_canvas_route.dart';
import 'ui/widgets/web_board_opener.dart';
import 'web_companion_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await WebDependencies.bootstrap();

  runApp(
    WebCompanionApp(
      service: dependencies.companionService,
      settingsService: dependencies.shared.settingsService,
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
