import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/services/invitation/invitation_service.dart';
import 'package:inklink/features/board_invitations/bloc/board_invitations_bloc.dart';
import 'package:inklink/features/board_invitations/view/board_invites_screen.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

class _FakeInvitationService implements InvitationService {
  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  int acceptCalls = 0;
  int declineCalls = 0;
  Completer<void>? gate;

  @override
  Future<void> acceptInvite(String inviteId) async {
    acceptCalls++;
    if (gate != null) await gate!.future;
  }

  @override
  Future<void> declineInvite(String inviteId) async {
    declineCalls++;
    if (gate != null) await gate!.future;
  }

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<List<Map<String, dynamic>>> watchPendingInvites() => controller.stream;

  Future<void> dispose() => controller.close();
}

void main() {
  test(
    'BoardInvitationsBloc silently ignores rapid duplicate accept/decline events',
    () async {
      final gate = Completer<void>();
      final service = _FakeInvitationService()..gate = gate;
      final bloc = BoardInvitationsBloc(invitationService: service);
      addTearDown(() async {
        await bloc.close();
        await service.dispose();
      });

      bloc.add(const BoardInvitationsLoadRequested());
      await Future<void>.delayed(Duration.zero);
      service.controller.add([
        {'id': 'inv-1', 'boardId': 'board-1', 'boardTitle': 'Board One'},
      ]);
      await bloc.stream.firstWhere((s) => s is BoardInvitationsLoaded);

      final done = Completer<bool>();
      bloc.add(
        BoardInvitationAcceptRequested(
          'inv-1',
          boardId: 'board-1',
          onCompleted: (ok, _) => done.complete(ok),
        ),
      );
      bloc.add(
        const BoardInvitationAcceptRequested('inv-1', boardId: 'board-1'),
      );
      bloc.add(const BoardInvitationDeclineRequested('inv-1'));

      await Future<void>.delayed(Duration.zero);
      expect(service.acceptCalls, 1);
      expect(service.declineCalls, 0);
      expect(
        (bloc.state as BoardInvitationsLoaded).processingInviteIds,
        contains('inv-1'),
      );

      gate.complete();
      expect(await done.future, isTrue);
      expect(service.acceptCalls, 1);
      expect(
        (bloc.state as BoardInvitationsLoaded).processingInviteIds,
        isEmpty,
      );
    },
  );

  testWidgets(
    'BoardInvitesScreen ignores rapid double taps and shows loading while pending',
    (tester) async {
      final gate = Completer<void>();
      final service = _FakeInvitationService()..gate = gate;
      final bloc = BoardInvitationsBloc(invitationService: service);
      addTearDown(() async {
        await bloc.close();
        await service.dispose();
      });

      final openedBoardIds = <String>[];
      await tester.pumpWidget(
        BlocProvider<BoardInvitationsBloc>.value(
          value: bloc,
          child: MaterialApp(
            theme: InkTheme.light(),
            home: BoardInvitesScreen(
              canvasRouteBuilder: (_, boardId) {
                openedBoardIds.add(boardId);
                return MaterialPageRoute<void>(builder: (_) => const SizedBox());
              },
            ),
          ),
        ),
      );
      await tester.pump();
      service.controller.add([
        {
          'id': 'inv-1',
          'boardId': 'board-1',
          'boardTitle': 'Board One',
          'senderName': 'Alice',
        },
      ]);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Accept'));
      await tester.tap(find.text('Accept'), warnIfMissed: false);
      await tester.pump();

      expect(service.acceptCalls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(service.acceptCalls, 1);
      expect(openedBoardIds, ['board-1']);
      expect(find.text('Invite accepted.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
