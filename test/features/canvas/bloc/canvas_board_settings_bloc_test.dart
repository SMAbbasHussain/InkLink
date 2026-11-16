import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/canvas/canvas_board_settings.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';

Future<CanvasState> _until(
  CanvasBloc bloc,
  bool Function(CanvasState) predicate,
) => bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 3));

class _Service extends Fake implements CanvasService {
  final writes = StreamController<Uint8List>.broadcast(sync: true);
  int count = 0;

  @override
  String? get currentClientId => 'author';
  @override
  Stream<Board?> watchBoardById(String id) => const Stream.empty();
  @override
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String id) =>
      const Stream.empty();
  @override
  Stream<List<LocalCrdtUpdate>> listenToCanvasPreviews(String id) =>
      const Stream.empty();
  @override
  Future<void> stopCrdtRemoteSync(String id) async {}
  @override
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required Uint8List payload,
  }) async {}
  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
  }) async {
    count++;
    writes.add(payload);
  }
}

void main() {
  test('Given a viewer, Then board settings are rejected', () async {
    final bloc = CanvasBloc();
    addTearDown(bloc.close);
    bloc.add(
      const CanvasSetBoardSettings(
        CanvasBoardSettings(backgroundColor: Color(0xFF000000)),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(bloc.state.boardSettings, CanvasBoardSettings.defaults);
  });

  test('Given an editor, Then settings persist as one CRDT payload and load on '
      'another client', () async {
    final adapter = await CanvasCrdtAdapter.create();
    final service = _Service();
    final bloc = CanvasBloc(
      crdtAdapter: adapter,
      canvasService: service,
      boardId: 'board',
    );
    addTearDown(() async {
      await bloc.close();
      await service.writes.close();
    });
    bloc.add(const CanvasInitializeCrdt('board'));
    await _until(bloc, (state) => !state.isLoading);
    bloc.add(
      const CanvasBoardTitleUpdated(
        null,
        currentUserRole: Board.roleEditor,
      ),
    );
    await _until(bloc, (state) => state.canEdit);

    const settings = CanvasBoardSettings(
      backgroundColor: Color(0xFF1E293B),
      backgroundPattern: CanvasBackgroundPattern.grid,
      patternSpacing: 40,
      pageBoundsEnabled: true,
      pageWidth: 1000,
      pageHeight: 700,
    );
    final write = service.writes.stream.first;
    bloc.add(const CanvasSetBoardSettings(settings));
    await write.timeout(const Duration(seconds: 3));
    expect(service.count, 1);
    expect(bloc.state.boardSettings, settings);
    expect(bloc.state.elements, isEmpty, reason: 'settings are not elements');

    final secondService = _Service();
    final second = CanvasBloc(
      crdtAdapter: adapter,
      canvasService: secondService,
      boardId: 'board',
    );
    addTearDown(() async {
      await second.close();
      await secondService.writes.close();
    });
    second.add(const CanvasInitializeCrdt('board'));

    final loaded = await _until(
      second,
      (state) => state.boardSettings.pageWidth == 1000,
    );
    expect(loaded.boardSettings, settings);
  });

  test('Given identical settings, Then no extra transaction is written',
      () async {
    final adapter = await CanvasCrdtAdapter.create();
    final service = _Service();
    final bloc = CanvasBloc(
      crdtAdapter: adapter,
      canvasService: service,
      boardId: 'board',
    );
    addTearDown(() async {
      await bloc.close();
      await service.writes.close();
    });
    bloc.add(const CanvasInitializeCrdt('board'));
    await _until(bloc, (state) => !state.isLoading);
    bloc.add(
      const CanvasBoardTitleUpdated(
        null,
        currentUserRole: Board.roleEditor,
      ),
    );
    await _until(bloc, (state) => state.canEdit);

    bloc.add(const CanvasSetBoardSettings(CanvasBoardSettings.defaults));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(service.count, 0);
  });
}
