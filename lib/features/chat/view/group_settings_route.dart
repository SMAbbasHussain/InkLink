import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  return MaterialPageRoute(
    builder: (_) => BlocProvider(
      create: (_) => GroupSettingsBloc(
        chatService: context.read<ChatService>(),
        currentUid: currentUid,
      )..add(LoadGroupSettings(groupId)),
      child: GroupSettingsScreen(groupId: groupId),
    ),
  );
}
