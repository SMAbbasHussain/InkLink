import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/chat/chat_conversation_model.dart';
import 'package:inklink/domain/models/chat/chat_message_model.dart';
import 'package:inklink/domain/services/auth/auth_session_service.dart';
import 'package:inklink/domain/services/chat/chat_service.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/chat/bloc/chat_thread_bloc.dart';
import 'package:inklink/features/chat/bloc/chat_thread_event.dart';
import 'package:inklink/features/chat/view/chat_thread_screen.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

const String _currentUid = 'current-user-uid';
const String _peerUid = 'peer-user-uid';

class _FakeChatService implements ChatService {
  _FakeChatService(this.messages);

  final List<ChatMessageModel> messages;
  final StreamController<List<ChatMessageModel>> _controller =
      StreamController<List<ChatMessageModel>>.broadcast();

  @override
  Stream<List<ChatMessageModel>> watchMessages(String conversationId) =>
      _controller.stream;

  @override
  Future<List<ChatMessageModel>> getMessages(String conversationId) async =>
      messages;

  @override
  Future<void> markConversationAsRead(String conversationId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthSessionService implements AuthSessionService {
  @override
  fb.User? get currentUser => null;

  @override
  Stream<fb.User?> get user => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatMessageModel _message(int index) {
  return ChatMessageModel(
    id: 'message-$index',
    conversationId: _peerUid,
    senderId: index.isEven ? _currentUid : _peerUid,
    senderName: index.isEven ? 'Me' : 'Peer',
    type: ChatMessageType.text,
    content: 'message $index',
    timestamp: DateTime(2026, 1, 1).add(Duration(minutes: index)),
    status: ChatMessageStatus.sent,
  );
}

void main() {
  testWidgets(
    'chat opens on the newest message and scrolls back through history',
    (tester) async {
      final messages = List<ChatMessageModel>.generate(40, _message);
      final chatService = _FakeChatService(messages);
      final conversation = ChatConversationModel(
        id: _peerUid,
        name: 'Peer',
        isGroup: false,
        memberIds: const [_currentUid, _peerUid],
      );

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ChatService>.value(value: chatService),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(
                value: AuthBloc(authService: _FakeAuthSessionService()),
              ),
              BlocProvider(
                create: (_) => ChatThreadBloc(
                  chatService: chatService,
                  currentUid: _currentUid,
                )..add(LoadChatThread(_peerUid)),
              ),
            ],
            child: MaterialApp(
              theme: InkTheme.light(),
              home: ChatThreadScreen(conversation: conversation),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A reversed list starts at the newest entry without any post-layout
      // jump, which is also what makes reopening a chat land on the latest
      // messages instead of the top.
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.reverse, isTrue);
      expect(find.text('message 39'), findsOneWidget);
      expect(find.text('message 0'), findsNothing);

      // The list must actually be scrollable (the reported bug was a thread
      // that could not scroll at all) and all older history reachable.
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('message 0'), findsOneWidget);
    },
  );
}
