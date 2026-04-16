import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/board/board_repository.dart';
import 'create_workspace_screen.dart';

Route<void> buildCreateWorkspaceRoute(BuildContext context) {
  final boardRepository = context.read<BoardRepository>();
  return MaterialPageRoute(
    builder: (_) => CreateWorkspaceScreen(
      ownedBoardsStream: boardRepository.getOwnedBoards(),
      joinedBoardsStream: boardRepository.getJoinedBoards(),
    ),
  );
}
