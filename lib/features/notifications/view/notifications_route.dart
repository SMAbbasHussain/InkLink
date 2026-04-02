import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/invitation/invitation_repository.dart';
import '../../../domain/repositories/notification/notification_repository.dart';
import '../../invitations/bloc/invitations_bloc.dart';
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
          create: (_) => InvitationsBloc(
            invitationRepository: context.read<InvitationRepository>(),
          )..add(const InvitationsLoadRequested()),
        ),
      ],
      child: const NotificationsScreen(),
    ),
  );
}
