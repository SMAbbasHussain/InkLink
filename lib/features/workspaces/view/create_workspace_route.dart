import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/board/board_service.dart';
import 'create_workspace_screen.dart';

Route<void> buildCreateWorkspaceRoute(BuildContext context) {
  final boardService = context.read<BoardService>();
  return MaterialPageRoute(
    builder: (_) => CreateWorkspaceScreen(
      ownedBoardsStream: boardService.getOwnedBoards(),
      joinedBoardsStream: boardService.getJoinedBoards(),
    ),
  );
}
