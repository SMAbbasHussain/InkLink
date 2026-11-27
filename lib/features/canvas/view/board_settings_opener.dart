import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/board.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../bloc/canvas_bloc.dart';
import '../../dashboard/view/board_settings_route.dart';

/// Opens the board settings screen from the canvas (phones).
///
/// Moved unchanged from `_CanvasScreenState._openSettings`. The web build
/// uses `board_settings_opener_web.dart` instead (see the conditional import
/// in canvas_screen.dart), because the settings screen reaches the phone
/// database.
void openBoardSettings(
  BuildContext context, {
  required String boardId,
  required String currentTitle,
  CanvasBloc? canvasBloc,
}) {
  final dashboardBloc = context.read<DashboardBloc>();
  final dashboardState = dashboardBloc.state;
  Board? board;

  if (dashboardState is DashboardLoaded) {
    for (final b in dashboardState.ownedBoards) {
      if (b.id == boardId) {
        board = b;
        break;
      }
    }
    if (board == null) {
      for (final b in dashboardState.joinedBoards) {
        if (b.id == boardId) {
          board = b;
          break;
        }
      }
    }
  }

  final fallback = Board(
    id: boardId,
    title: currentTitle,
    ownerId: '',
    members: const [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Navigator.push(
    context,
    buildBoardSettingsRoute(
      context,
      board: board ?? fallback,
      canvasBloc: canvasBloc,
    ),
  );
}
