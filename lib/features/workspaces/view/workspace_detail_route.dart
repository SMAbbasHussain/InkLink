import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/board/board_service.dart';
import 'workspace_detail_screen.dart';

Route<void> buildWorkspaceDetailRoute(
  BuildContext context,
  String workspaceId,
) {
  final boardService = context.read<BoardService>();
  final ownedBoardsStream = boardService
      .getOwnedBoards()
      .asBroadcastStream();
  final joinedBoardsStream = boardService
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
