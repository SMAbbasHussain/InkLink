import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/models/chat/chat_conversation_model.dart';
import '../../../../domain/services/chat/chat_service.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import 'create_group_screen.dart';

Route<ChatConversationModel> buildCreateGroupRoute(BuildContext context) {
  final authState = context.read<AuthBloc>().state;
  final currentUid = authState is Authenticated ? authState.uid : '';
  final currentEmail =
      authState is Authenticated ? (authState.email ?? '') : '';

  return MaterialPageRoute(
    builder: (_) => CreateGroupScreen(
      chatService: context.read<ChatService>(),
      currentUserId: currentUid,
      currentUserEmail: currentEmail,
    ),
  );
}
