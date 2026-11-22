import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/board.dart';
import '../../../domain/services/board/board_service.dart';
import '../../../domain/services/friends/friends_service.dart';
import '../../canvas/bloc/canvas_bloc.dart';
import '../bloc/board_settings_bloc.dart';
import 'board_settings_screen.dart';

Route<void> buildBoardSettingsRoute(
  BuildContext context, {
  required Board board,
  CanvasBloc? canvasBloc,
}) {
  FriendsService? friendsService;
  try {
    friendsService = context.read<FriendsService>();
  } catch (_) {}

  return MaterialPageRoute(
    builder: (_) => BlocProvider(
      create: (_) => BoardSettingsBloc(
        boardService: context.read<BoardService>(),
        friendsService: friendsService,
      )..add(BoardSettingsStarted(board.id)),
      child: BoardSettingsScreen(board: board, canvasBloc: canvasBloc),
    ),
  );
}
