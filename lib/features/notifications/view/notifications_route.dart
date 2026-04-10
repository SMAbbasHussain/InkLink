import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/notification/notification_repository.dart';
import '../../../domain/services/invitation/invitation_service.dart';
import '../../board_invitations/bloc/board_invitations_bloc.dart';
import '../bloc/notifications_bloc.dart';
import 'notifications_screen.dart';

Route<void> buildNotificationsRoute(BuildContext context) {
  return MaterialPageRoute(
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => NotificationsBloc(
            notificationRepository: context.read<NotificationRepository>(),
          )..add(const NotificationsLoadRequested()),
        ),
        BlocProvider(
          create: (_) => BoardInvitationsBloc(
            invitationService: context.read<InvitationService>(),
          )..add(const BoardInvitationsLoadRequested()),
        ),
      ],
      child: const NotificationsScreen(),
    ),
  );
}
