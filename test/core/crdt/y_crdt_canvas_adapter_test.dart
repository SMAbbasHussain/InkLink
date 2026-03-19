import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/y_crdt_canvas_adapter.dart';

void main() {
  final hasWasmAsset = File('lib/assets/y_crdt_wasm.wasm').existsSync();

  group('YCrdtCanvasAdapter', () {
    test(
      'converges when updates arrive in different order',
      () async {
        final source = await YCrdtCanvasAdapter.create();
        final peer = await YCrdtCanvasAdapter.create();

        final u1 = source.upsertElement('a', {
          'type': 'shape',
          'shapeType': 'circle',
          'cx': 50,
          'cy': 60,
          'size': 40,
          'color': 0xFF000000,
        });
        final u2 = source.upsertElement('b', {
          'type': 'text',
          'text': 'hello',
          'cx': 10,
          'cy': 20,
          'color': 0xFF111111,
        });
        final u3 = source.deleteElement('a');

        peer.applyUpdate(u2);
        peer.applyUpdate(u1);
        peer.applyUpdate(u3);

        expect(
          peer.materializeElements(),
          equals(source.materializeElements()),
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
      skip: !hasWasmAsset,
    );

    test(
      'undo and redo are collaborative through shared updates',
      () async {
        final clientA = await YCrdtCanvasAdapter.create();
        final clientB = await YCrdtCanvasAdapter.create();

        final createUpdate = clientA.upsertElement('x', {
          'type': 'text',
          'text': 'sync',
          'cx': 1,
          'cy': 2,
          'color': 0xFF222222,
        });
        clientB.applyUpdate(createUpdate);

        final undoUpdate = clientA.undoLast();
        expect(undoUpdate, isNotNull);
        clientB.applyUpdate(undoUpdate!);

        expect(clientA.materializeElements().containsKey('x'), isFalse);
        expect(clientB.materializeElements().containsKey('x'), isFalse);

        final redoUpdate = clientA.redoLast();
        expect(redoUpdate, isNotNull);
        clientB.applyUpdate(redoUpdate!);

        expect(clientA.materializeElements().containsKey('x'), isTrue);
        expect(clientB.materializeElements().containsKey('x'), isTrue);
        expect(
          clientB.materializeElements(),
          equals(clientA.materializeElements()),
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
      skip: !hasWasmAsset,
    );
  });
}
