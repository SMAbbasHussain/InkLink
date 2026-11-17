import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';

class _FakeCanvasService extends Fake implements CanvasService {
  final writes = StreamController<Uint8List>.broadcast(sync: true);

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
    String action = 'upsert',
  }) async {
    writes.add(payload);
  }
}

Future<CanvasState> _until(CanvasBloc bloc, bool Function(CanvasState) test) =>
    bloc.stream.firstWhere(test).timeout(const Duration(seconds: 3));

void main() {
  group('F-16 Table model & geometry', () {
    test('Given table payload, When serialized & restored, Then cells and fractions match', () {
      const table = TableElement(
        id: 't1',
        z: 4,
        center: Offset(200, 120),
        width: 300,
        height: 150,
        rows: 2,
        columns: 3,
        cells: [
          TableCellData(text: 'H1', fontWeight: 700, textAlign: 'center'),
          TableCellData(text: 'H2'),
          TableCellData(text: 'H3'),
          TableCellData(text: 'R1C1', backgroundColor: Color(0xFFDBEAFE)),
          TableCellData(text: 'R1C2'),
          TableCellData(text: 'R1C3'),
        ],
        columnFractions: [0.5, 0.25, 0.25],
        rowFractions: [0.4, 0.6],
        headerRow: true,
        borderColor: Color(0xFF2563EB),
        borderWidth: 2,
        rotation: 0.2,
      );

      final roundTripped =
          CanvasElement.fromMap('t1', table.toMap()) as TableElement;
      expect(roundTripped, equals(table));
      expect(roundTripped.cellAt(1, 0).backgroundColor, const Color(0xFFDBEAFE));
      expect(roundTripped.columnFractions, [0.5, 0.25, 0.25]);
    });

    test('Given rotated and unrotated tables, When tableHitTestCell runs, Then it maps row/col accurately', () {
      const unrotated = TableElement(
        id: 't-unrot',
        z: 0,
        center: Offset(0, 0),
        width: 300,
        height: 120,
        rows: 2,
        columns: 3,
      );
      expect(tableHitTestCell(unrotated, const Offset(-100, -30)), (0, 0));
      expect(tableHitTestCell(unrotated, const Offset(0, -30)), (0, 1));
      expect(tableHitTestCell(unrotated, const Offset(100, 30)), (1, 2));
      expect(tableHitTestCell(unrotated, const Offset(200, 0)), isNull);

      final rotated = unrotated.copyWith(rotation: math.pi / 2);
      // With 90deg clockwise rotation, local (-100, -30) lands at (30, -100).
      expect(tableHitTestCell(rotated, const Offset(30, -100)), (0, 0));
    });
  });

  group('F-16 Table BLoC & export', () {
    test('Given editor, When inserting/editing/modifying table rows & cols, Then CRDT rebuilds & undo works', () async {
      final adapter = await CanvasDocAdapterFactory.create();
      final service = _FakeCanvasService();
      final bloc = CanvasBloc(
        crdtAdapter: adapter,
        canvasService: service,
        boardId: 'b',
      );
      addTearDown(() async {
        await bloc.close();
        await service.writes.close();
      });
      bloc.add(const CanvasInitializeCrdt('b'));
      await _until(bloc, (s) => !s.isLoading);

      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
      );
      await _until(bloc, (s) => s.canEdit);

      bloc.add(const CanvasAddTable(center: Offset(100, 100), rows: 2, columns: 2));
      await _until(bloc, (s) => s.elements.whereType<TableElement>().length == 1);
      final table = bloc.state.elements.whereType<TableElement>().single;
      expect(table.rows, 2);
      expect(table.columns, 2);

      bloc.add(
        CanvasUpdateTableCell(
          tableId: table.id,
          row: 0,
          column: 1,
          text: 'Owner <A & B>',
          fontWeight: 700,
          textAlign: 'center',
        ),
      );
      await _until(
        bloc,
        (s) =>
            s.elements.whereType<TableElement>().single.cellAt(0, 1).text ==
            'Owner <A & B>',
      );

      bloc.add(CanvasUpdateTableStyle(tableId: table.id, insertRowAt: 2));
      await _until(
        bloc,
        (s) => s.elements.whereType<TableElement>().single.rows == 3,
      );

      bloc.add(CanvasUpdateTableStyle(tableId: table.id, insertColumnAt: 2));
      await _until(
        bloc,
        (s) => s.elements.whereType<TableElement>().single.columns == 3,
      );

      bloc.add(CanvasUpdateTableStyle(tableId: table.id, removeRowAt: 1));
      await _until(
        bloc,
        (s) => s.elements.whereType<TableElement>().single.rows == 2,
      );

      bloc.add(CanvasUpdateTableStyle(tableId: table.id, removeColumnAt: 0));
      await _until(
        bloc,
        (s) => s.elements.whereType<TableElement>().single.columns == 2,
      );
      final shrunk = bloc.state.elements.whereType<TableElement>().single;
      // Removing column 0 shifts old col 1 ('Owner <A & B>') into col 0.
      expect(shrunk.cellAt(0, 0).text, 'Owner <A & B>');

      // Resize respects minimum per-cell bounds
      bloc.add(const CanvasResizeSelectedShape(10, width: 10, height: 10));
      await _until(
        bloc,
        (s) => s.elements.whereType<TableElement>().single.width < shrunk.width,
      );
      final clamped = bloc.state.elements.whereType<TableElement>().single;
      expect(clamped.width, TableElement.minCellWidth * clamped.columns);
      expect(clamped.height, TableElement.minCellHeight * clamped.rows);

      // Rebuilds identically into another replica
      final replica = CanvasBloc(crdtAdapter: adapter);
      addTearDown(replica.close);
      replica.add(const CanvasInitializeCrdt('b'));
      await _until(replica, (s) => !s.isLoading && s.elements.isNotEmpty);
      expect(
        replica.state.elements.whereType<TableElement>().single.cellAt(0, 0).text,
        'Owner <A & B>',
      );
    });

    test('Given large dimension request, When CanvasAddTable runs, Then maxTotalCells guard caps cells <= 200', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
      );
      await _until(bloc, (s) => s.canEdit);

      bloc.add(
        const CanvasAddTable(center: Offset.zero, rows: 20, columns: 20),
      );
      await _until(bloc, (s) => s.elements.whereType<TableElement>().isNotEmpty);
      final table = bloc.state.elements.whereType<TableElement>().single;
      expect(table.rows * table.columns, lessThanOrEqualTo(TableElement.maxTotalCells));
    });

    test('Given viewer role, When table events run, Then mutations are rejected', () async {
      final adapter = await CanvasDocAdapterFactory.create();
      adapter.upsertElement(
        't',
        const TableElement(id: 't', z: 0, center: Offset.zero).toMap(),
      );
      final bloc = CanvasBloc(crdtAdapter: adapter);
      addTearDown(bloc.close);
      bloc.add(const CanvasInitializeCrdt('b'));
      await _until(bloc, (s) => !s.isLoading && s.elements.length == 1);
      expect(bloc.state.canEdit, isFalse);

      bloc.add(
        const CanvasUpdateTableCell(tableId: 't', row: 0, column: 0, text: 'No'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        bloc.state.elements.whereType<TableElement>().single.cellAt(0, 0).text,
        '',
      );
    });

    test('Given a TableElement, When exported to SVG, PNG and PDF, Then all formats succeed', () async {
      const exportService = BoardExportServiceImpl();
      const table = TableElement(
        id: 't-exp',
        z: 0,
        center: Offset(100, 100),
        rows: 2,
        columns: 2,
        cells: [
          TableCellData(text: 'Task & Status'),
          TableCellData(text: 'ETA'),
          TableCellData(text: 'Ship'),
          TableCellData(text: 'Today'),
        ],
      );

      final svg = exportService.renderToSvg('Table Board', [table]);
      expect(svg, contains('Task &amp; Status'));
      expect(svg, contains('<line '));
      expect(svg, contains('<rect '));

      final png = await exportService.renderToPng([table]);
      expect(png, isNotEmpty);

      final pdf = await exportService.renderToPdf('Table Board', [table]);
      expect(pdf, isNotEmpty);
    });
  });
}
