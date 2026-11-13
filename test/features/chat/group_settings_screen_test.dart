import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/chat/chat_conversation_model.dart';
import 'package:inklink/domain/services/auth/auth_session_service.dart';
import 'package:inklink/domain/services/chat/chat_service.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/chat/bloc/group_settings_bloc.dart';
import 'package:inklink/features/chat/bloc/group_settings_event.dart';
import 'package:inklink/features/chat/view/group_settings_screen.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

const String _ownerUid = 'owner-uid';

final ChatConversationModel _group = ChatConversationModel(
  id: 'group-1',
  name: 'fyp',
  description: 'fyp',
  isGroup: true,
  ownerId: _ownerUid,
  adminIds: const [_ownerUid],
  memberIds: const [_ownerUid, 'member-2', 'member-3'],
);

class _FakeChatService implements ChatService {
  @override
  Future<List<ChatConversationModel>> getConversations() async => [_group];

  @override
  Future<Map<String, ChatMemberProfile>> getMemberProfiles(
    List<String> uids,
  ) async =>
      const {};

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

void main() {
  testWidgets(
    'group details renders its member list without the sliver context.select crash',
    (tester) async {
      final chatService = _FakeChatService();

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
                create: (_) => GroupSettingsBloc(
                  chatService: chatService,
                  currentUid: _ownerUid,
                )..add(const LoadGroupSettings('group-1')),
              ),
            ],
            child: MaterialApp(
              theme: InkTheme.light(),
              home: const GroupSettingsScreen(groupId: 'group-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The previously crashing tree built the whole member ListView with a
      // `context.select` in its itemBuilder.
      expect(find.text('Group Details'), findsOneWidget);
      expect(find.text('fyp'), findsWidgets);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
      expect(find.text('User membe'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
