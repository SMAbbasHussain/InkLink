import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/board/board_service.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:inklink/ui/widgets/board_card_frame.dart';

class _FakeCanvasService extends Fake implements CanvasService {
  Completer<void>? saveGate;
  Uint8List? savedBytes;
  String? savedBoardId;

  @override
  bool get canSync => true;

  @override
  String? get currentClientId => 'owner-1';

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {
    savedBoardId = boardId;
    savedBytes = pngBytes;
    if (saveGate != null) {
      await saveGate!.future;
    }
  }

  @override
  Stream<Board?> watchBoardById(String boardId) => const Stream.empty();

  @override
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String boardId) =>
      const Stream.empty();

  @override
  Stream<List<LocalCrdtUpdate>> listenToCanvasPreviews(String boardId) =>
      const Stream.empty();

  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
    String action = 'upsert',
  }) async {}

  @override
  Future<void> stopCrdtRemoteSync(String boardId) async {}
}

class _FakeBoardService extends Fake implements BoardService {
  bool? lastSetPaused;

  @override
  Stream<List<BoardMember>> getBoardMembers(String boardId) =>
      const Stream.empty();

  @override
  Future<void> setBoardPaused(String boardId, {required bool isPaused}) async {
    lastSetPaused = isPaused;
  }
}

void main() {
  group('Board pause state & preview save', () {
    test('paused board disables editing even for owner until resumed', () async {
      final bloc = CanvasBloc(
        currentUserId: 'owner-1',
        boardId: 'board-1',
      );
      addTearDown(() => bloc.close());

      bloc.add(
        const CanvasBoardTitleUpdated(
          'Team Board',
          currentUserRole: Board.roleOwner,
          isPaused: true,
        ),
      );
      await pumpEventQueue();

      expect(bloc.state.isPaused, isTrue);
      expect(bloc.state.canEdit, isFalse);

      bloc.add(const CanvasStartStroke(Offset(10, 10)));
      await pumpEventQueue();

      expect(bloc.state.currentStroke, isEmpty);
      expect(bloc.state.error, contains('paused'));

      bloc.add(
        const CanvasBoardTitleUpdated(
          'Team Board',
          currentUserRole: Board.roleOwner,
          isPaused: false,
        ),
      );
      await pumpEventQueue();

      expect(bloc.state.isPaused, isFalse);
      expect(bloc.state.canEdit, isTrue);
    });

    test(
      'CanvasSaveBoardPreviewRequested waits for preview persistence before completing',
      () async {
        final canvasService = _FakeCanvasService()
          ..saveGate = Completer<void>();
        final bloc = CanvasBloc(
          canvasService: canvasService,
          currentUserId: 'owner-1',
          boardId: 'board-preview-1',
        );
        addTearDown(() => bloc.close());

        final done = Completer<void>();
        bloc.add(
          CanvasSaveBoardPreviewRequested(
            Uint8List.fromList([137, 80, 78, 71]),
            completer: done,
          ),
        );
        await pumpEventQueue();

        expect(canvasService.savedBoardId, 'board-preview-1');
        expect(done.isCompleted, isFalse);

        canvasService.saveGate!.complete();
        await done.future;

        expect(done.isCompleted, isTrue);
        expect(canvasService.savedBytes, [137, 80, 78, 71]);
      },
    );

    test(
      'CanvasSetBoardPausedRequested toggles pause state and persists via boardService',
      () async {
        final boardService = _FakeBoardService();
        final bloc = CanvasBloc(
          boardService: boardService,
          currentUserId: 'owner-1',
          boardId: 'board-1',
        );
        addTearDown(() => bloc.close());

        bloc.add(
          const CanvasBoardTitleUpdated(
            'Paused Board',
            currentUserRole: Board.roleOwner,
            isPaused: true,
          ),
        );
        await pumpEventQueue();

        expect(bloc.state.isPaused, isTrue);
        expect(bloc.state.canEdit, isFalse);

        bloc.add(const CanvasSetBoardPausedRequested(false));
        await pumpEventQueue();

        expect(boardService.lastSetPaused, isFalse);
        expect(bloc.state.isPaused, isFalse);
        expect(bloc.state.canEdit, isTrue);
        expect(bloc.state.infoMessage, contains('resumed'));
      },
    );

    testWidgets('BoardCardFrame shows Paused badge and handles missing/empty preview', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Scaffold(
            body: BoardCardFrame(
              previewPath: 'non_existent_or_empty.png',
              title: 'Board A',
              caption: 'Edited just now',
              isPaused: true,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Paused'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
