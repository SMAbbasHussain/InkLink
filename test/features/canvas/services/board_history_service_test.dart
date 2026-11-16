import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/services/board_history_service.dart';

void main() {
  late Directory directory;
  late BoardHistoryService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('inklink-history-');
    service = BoardHistoryService(directoryProvider: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('Given checkpoints, Then they round-trip and stay capped', () async {
    final element = StrokeElement(
      id: 'stroke-1',
      z: 0,
      color: Colors.black,
      points: const [Offset(0, 0), Offset(10, 10)],
    );

    for (var i = 0; i < BoardHistoryService.maxEntries + 2; i++) {
      final saved = await service.save('board/with unsafe chars', [
        element,
      ], label: 'Version $i');
      expect(saved, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    final entries = await service.load('board/with unsafe chars');
    expect(entries.length, BoardHistoryService.maxEntries);
    expect(entries.first.label, isNotEmpty);
    expect(entries.first.elements.single['id'], 'stroke-1');
    expect(entries.first.elements.single['data'], isA<Map>());
    expect((entries.first.elements.single['data'] as Map)['type'], 'stroke');

    await service.delete('board/with unsafe chars', entries.first.id);
    expect(
      (await service.load('board/with unsafe chars')).length,
      BoardHistoryService.maxEntries - 1,
    );
  });

  test('Given an empty board, Then no checkpoint is written', () async {
    final saved = await service.save('empty', const []);
    expect(saved, isNull);
    expect(await service.load('empty'), isEmpty);
  });
}
