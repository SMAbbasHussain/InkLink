import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/services/board/board_service.dart';
import '../../../domain/services/profile/profile_service.dart';
import '../bloc/public_boards/public_boards_bloc.dart';
import '../bloc/public_boards/public_boards_event.dart';
import 'public_board_discovery_screen.dart';

Route<void> buildPublicBoardDiscoveryRoute(BuildContext context) {
  return MaterialPageRoute<void>(
    builder: (routeContext) {
      return BlocProvider<PublicBoardsBloc>(
        create: (blocContext) => PublicBoardsBloc(
          boardService: blocContext.read<BoardService>(),
          profileService: blocContext.read<ProfileService>(),
        )..add(const PublicBoardsFetchStarted()),
        child: const PublicBoardDiscoveryScreen(),
      );
    },
  );
}
