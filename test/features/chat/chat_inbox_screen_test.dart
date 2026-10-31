import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inklink/domain/models/chat/chat_conversation_model.dart';
import 'package:inklink/domain/services/auth/auth_session_service.dart';
import 'package:inklink/domain/services/chat/chat_service.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/chat/view/chat_inbox_screen.dart';
import 'package:inklink/features/chat/bloc/chat_inbox_bloc.dart';
import 'package:inklink/features/chat/bloc/chat_inbox_event.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:inklink/ui/widgets/empty_state.dart';

class MockChatService implements ChatService {
  @override
  Future<List<ChatConversationModel>> getConversations() async => [];

  @override
  Stream<List<ChatConversationModel>> watchConversations() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthSessionService implements AuthSessionService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get user => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ChatInboxScreen empty state renders cleanly with Desk theme', (tester) async {
    final mockService = MockChatService();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ChatService>.value(value: mockService),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(
              value: AuthBloc(authService: FakeAuthSessionService()),
            ),
          ],
          child: BlocProvider(
            create: (_) => ChatInboxBloc(chatService: mockService)..add(const LoadChatInbox()),
            child: MaterialApp(
              theme: InkTheme.light(),
              home: const ChatInboxScreen(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(
      find.text('Start a direct message with friends or create a new group chat to begin collaborating.'),
      findsOneWidget,
    );
    expect(find.text('New Chat'), findsOneWidget);
    expect(find.text('New Group'), findsOneWidget);

    final emptyStateRect = tester.getRect(find.byType(EmptyState));
    final newChatRect = tester.getRect(find.text('New Chat'));
    final newGroupRect = tester.getRect(find.text('New Group'));

    // Verify vertically sequential placement: button row must be below EmptyState sticky note
    expect(newChatRect.top, greaterThanOrEqualTo(emptyStateRect.bottom));
    expect(newGroupRect.top, greaterThanOrEqualTo(emptyStateRect.bottom));
  });

  testWidgets('ChatInboxScreen app bar has friend request and new conversation buttons', (tester) async {
    final mockService = MockChatService();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ChatService>.value(value: mockService),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(
              value: AuthBloc(authService: FakeAuthSessionService()),
            ),
          ],
          child: BlocProvider(
            create: (_) => ChatInboxBloc(chatService: mockService)..add(const LoadChatInbox()),
            child: MaterialApp(
              theme: InkTheme.light(),
              home: const ChatInboxScreen(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify Add Collaborator action button exists
    expect(find.byTooltip('Add Collaborator'), findsOneWidget);
    expect(find.byTooltip('New Conversation'), findsOneWidget);

    // Tap 'New Conversation' button
    await tester.tap(find.byTooltip('New Conversation'));
    await tester.pumpAndSettle();

    // Bottom sheet should appear with options
    expect(find.text('New Conversation'), findsWidgets);
    expect(find.text('Choose the type of conversation to start'), findsOneWidget);
    expect(find.text('Direct Message'), findsOneWidget);
    expect(find.text('Group Chat'), findsOneWidget);
  });
}
