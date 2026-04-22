import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/board/board_repository.dart';
import 'workspace_detail_screen.dart';

Route<void> buildWorkspaceDetailRoute(
  BuildContext context,
  String workspaceId,
) {
  final boardRepository = context.read<BoardRepository>();
  final ownedBoardsStream = boardRepository
      .getOwnedBoards()
      .asBroadcastStream();
  final joinedBoardsStream = boardRepository
      .getJoinedBoards()
      .asBroadcastStream();
  return MaterialPageRoute(
    builder: (_) => WorkspaceDetailScreen(
      workspaceId: workspaceId,
      ownedBoardsStream: ownedBoardsStream,
      joinedBoardsStream: joinedBoardsStream,
    ),
  );
}
