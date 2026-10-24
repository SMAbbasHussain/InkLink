import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/local_database_service.dart';
import '../../../../domain/services/chat/chat_service.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/group_settings_bloc.dart';
import '../bloc/group_settings_event.dart';
import 'group_settings_screen.dart';

Route<void> buildGroupSettingsRoute(
  BuildContext context, {
  required String groupId,
}) {
  final authState = context.read<AuthBloc>().state;
  final currentUid = authState is Authenticated ? authState.uid : '';
  final localDb = context.read<LocalDatabaseService>();

  return MaterialPageRoute(
    builder: (_) => BlocProvider(
      create: (_) => GroupSettingsBloc(
        chatService: context.read<ChatService>(),
        currentUid: currentUid,
        localDbService: localDb,
      )..add(LoadGroupSettings(groupId)),
      child: GroupSettingsScreen(groupId: groupId),
    ),
  );
}
