import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/models/chat/chat_conversation_model.dart';
import '../../../../domain/services/chat/chat_service.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/chat_thread_bloc.dart';
import '../bloc/chat_thread_event.dart';
import 'chat_thread_screen.dart';

Route<void> buildChatThreadRoute(
  BuildContext context, {
  required ChatConversationModel conversation,
}) {
  final authState = context.read<AuthBloc>().state;
  final currentUid = authState is Authenticated ? authState.uid : '';

  return MaterialPageRoute(
    builder: (_) => BlocProvider(
      create: (_) => ChatThreadBloc(
        chatService: context.read<ChatService>(),
        currentUid: currentUid,
      )..add(LoadChatThread(conversation.id)),
      child: ChatThreadScreen(conversation: conversation),
    ),
  );
}
