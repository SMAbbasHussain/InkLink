import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inklink/features/chat/view/widgets/message_reactions_sheet.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/core/services/firestore_service.dart';
import 'package:inklink/core/database/local_database_service.dart';

class FakeAuthService implements AuthService {
  final String uid;
  final String displayName;
  final String? photoURL;

  FakeAuthService({
    this.uid = 'current-user-uid',
    this.displayName = 'Current User',
    this.photoURL,
  });

  @override
  User? getCurrentUser() => null;

  @override
  String? getCurrentUserId() => uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirestoreService implements FirestoreService {
  int getCallCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocalDatabaseService implements LocalDatabaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createTestableWidget({
  required Map<String, List<String>> reactions,
  required String currentUid,
  String? senderId,
  String? senderName,
  String? senderAvatar,
  Function(String emoji)? onReactionToggled,
}) {
  return MultiProvider(
    providers: [
      Provider<AuthService>(create: (_) => FakeAuthService(uid: currentUid)),
      Provider<FirestoreService>(create: (_) => FakeFirestoreService()),
      Provider<LocalDatabaseService>(create: (_) => FakeLocalDatabaseService()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: MessageReactionsSheet(
          reactions: reactions,
          currentUid: currentUid,
          senderId: senderId,
          senderName: senderName,
          senderAvatar: senderAvatar,
          onReactionToggled: onReactionToggled,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('MessageReactionsSheet displays header and reaction count', (tester) async {
    await tester.pumpWidget(
      createTestableWidget(
        reactions: {
          '❤️': ['current-user-uid', 'user-2'],
          '🔥': ['user-3'],
        },
        currentUid: 'current-user-uid',
      ),
    );

    await tester.pump();

    expect(find.text('Reactions'), findsOneWidget);
    expect(find.text('3'), findsWidgets); // Total count badge
    expect(find.text('All 3'), findsOneWidget);
    expect(find.text('❤️ 2'), findsOneWidget);
    expect(find.text('🔥 1'), findsOneWidget);
  });

  testWidgets('MessageReactionsSheet labels current user reaction with "You"', (tester) async {
    await tester.pumpWidget(
      createTestableWidget(
        reactions: {
          '👍': ['current-user-uid'],
        },
        currentUid: 'current-user-uid',
      ),
    );

    await tester.pump();

    expect(find.text('You'), findsWidgets);
    expect(find.text('Tap to remove reaction'), findsOneWidget);
  });

  testWidgets('MessageReactionsSheet displays senderName when senderId matches', (tester) async {
    await tester.pumpWidget(
      createTestableWidget(
        reactions: {
          '🎉': ['sender-uid'],
        },
        currentUid: 'other-uid',
        senderId: 'sender-uid',
        senderName: 'Alice Sender',
      ),
    );

    await tester.pump();

    expect(find.text('Alice Sender'), findsOneWidget);
  });

  testWidgets('Filter chip toggles reactors list display', (tester) async {
    await tester.pumpWidget(
      createTestableWidget(
        reactions: {
          '❤️': ['current-user-uid'],
          '😂': ['user-2'],
        },
        currentUid: 'current-user-uid',
      ),
    );

    await tester.pump();

    expect(find.text('❤️ 1'), findsOneWidget);
    expect(find.text('😂 1'), findsOneWidget);

    // Tap on the '😂 1' filter chip
    await tester.tap(find.text('😂 1'));
    await tester.pumpAndSettle();

    // Now only the '😂' reaction item should be in the list
    expect(find.text('😂'), findsWidgets);
    expect(find.text('❤️'), findsNothing);
  });
}
