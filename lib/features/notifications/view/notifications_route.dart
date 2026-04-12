import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/features/notifications/view/notifications_screen.dart';
import '../bloc/notifications_bloc.dart';
import '../../board_invitations/bloc/board_invitations_bloc.dart';


Route<void> buildNotificationsRoute(BuildContext context) {
  return MaterialPageRoute(
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<NotificationsBloc>()),
        BlocProvider.value(value: context.read<BoardInvitationsBloc>()),
      ],
      child: const NotificationsScreen(),
    ),
  );
}
