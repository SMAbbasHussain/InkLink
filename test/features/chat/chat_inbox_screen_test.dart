import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:inklink/domain/services/chat/chat_service.dart';
import 'package:inklink/features/chat/view/chat_inbox_screen.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:inklink/ui/widgets/empty_state.dart';

class MockChatService extends Mock implements ChatService {}

void main() {
  testWidgets('ChatInboxScreen empty state renders cleanly with Desk theme', (tester) async {
    final mockService = MockChatService();
    when(() => mockService.getConversations()).thenAnswer((_) async => []);
    when(() => mockService.watchConversations()).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ChatService>.value(value: mockService),
        ],
        child: MaterialApp(
          theme: InkTheme.light(),
          home: const ChatInboxScreen(),
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
}
