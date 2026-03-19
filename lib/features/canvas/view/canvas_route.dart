import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/board/board_repository.dart';
import '../../../domain/repositories/canvas/canvas_sync_repository.dart';
import '../bloc/canvas_bloc.dart';
import 'canvas_screen.dart';

Route<void> buildCanvasRoute(
  BuildContext context, {
  required String boardId,
  bool showTrayTipsOnEntry = false,
}) {
  return MaterialPageRoute(
    builder: (_) => BlocProvider(
      create: (_) =>
          CanvasBloc(
              boardRepository: context.read<BoardRepository>(),
              syncRepository: context.read<CanvasSyncRepository>(),
              boardId: boardId,
            )
            ..add(const CanvasStartBoardSyncRequested())
            ..add(CanvasInitializeCrdt(boardId)),
      child: CanvasScreen(
        boardId: boardId,
        showTrayTipsOnEntry: showTrayTipsOnEntry,
      ),
    ),
  );
}
