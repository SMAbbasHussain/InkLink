import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';

void main() {
  group('CanvasCrdtAdapter', () {
    test(
      'converges when updates arrive in different order',
      () async {
        final source = await CanvasCrdtAdapter.create();
        final peer = await CanvasCrdtAdapter.create();

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
    );

    test(
      'a batched write undoes and redoes as one step',
      () async {
        final adapter = await CanvasCrdtAdapter.create();
        final peer = await CanvasCrdtAdapter.create();

        Map<String, dynamic> shape(double cx) => {
              'type': 'shape',
              'z': 0,
              'shapeType': 'square',
              'cx': cx,
              'cy': 0,
              'size': 40,
              'color': 0xFF000000,
              'strokeWidth': 2,
            };

        final seeded = adapter.applyBatch([
          (id: 'a', payload: shape(0)),
          (id: 'b', payload: shape(100)),
          (id: 'c', payload: shape(200)),
        ]);
        peer.applyUpdate(seeded);
        // Separate the transactions so the undo manager cannot merge them.
        await Future<void>.delayed(const Duration(milliseconds: 600));

        final moved = adapter.applyBatch([
          (id: 'a', payload: shape(500)),
          (id: 'b', payload: shape(500)),
          (id: 'c', payload: shape(500)),
        ]);
        peer.applyUpdate(moved);
        expect(adapter.materializeElements()['a']!['cx'], 500);
        expect(peer.materializeElements()['c']!['cx'], 500);

        final undo = adapter.undoLast();
        expect(undo, isNotNull);
        peer.applyUpdate(undo!);

        // One undo restores every element in the batch.
        for (final id in ['a', 'b', 'c']) {
          expect(adapter.materializeElements()[id]!['cx'], isNot(500));
          expect(peer.materializeElements()[id]!['cx'],
              adapter.materializeElements()[id]!['cx']);
        }
        expect(adapter.materializeElements()['a']!['cx'], 0);
        expect(adapter.materializeElements()['b']!['cx'], 100);
        expect(adapter.materializeElements()['c']!['cx'], 200);

        final redo = adapter.redoLast();
        expect(redo, isNotNull);
        peer.applyUpdate(redo!);
        for (final id in ['a', 'b', 'c']) {
          expect(adapter.materializeElements()[id]!['cx'], 500);
          expect(peer.materializeElements()[id]!['cx'], 500);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'a batch delete and update undo together',
      () async {
        final adapter = await CanvasCrdtAdapter.create();
        Map<String, dynamic> shape(double cx) => {
              'type': 'shape',
              'z': 0,
              'shapeType': 'square',
              'cx': cx,
              'cy': 0,
              'size': 40,
              'color': 0xFF000000,
              'strokeWidth': 2,
            };

        adapter.applyBatch([
          (id: 'keep', payload: shape(100)),
          (id: 'gone', payload: shape(200)),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 600));

        adapter.applyBatch([
          (id: 'gone', payload: null),
          (id: 'keep', payload: shape(300)),
        ]);
        expect(adapter.materializeElements().containsKey('gone'), isFalse);
        expect(adapter.materializeElements()['keep']!['cx'], 300);

        adapter.undoLast();
        final restored = adapter.materializeElements();
        expect(restored.containsKey('gone'), isTrue);
        expect(restored['keep']!['cx'], 100);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'undo and redo are collaborative through shared updates',
      () async {
        final clientA = await CanvasCrdtAdapter.create();
        final clientB = await CanvasCrdtAdapter.create();

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
    );

    test(
      'handles updates with gaps and deletions without throwing Skip type cast error',
      () async {
        final source = await CanvasCrdtAdapter.create();
        source.upsertElement('e1', {'type': 'shape', 'val': 1});
        final svAfter1 = source.encodeStateVector();

        // Second update creates e2 and deletes e1
        source.upsertElement('e2', {'type': 'shape', 'val': 2});
        source.deleteElement('e1');

        final delta = source.encodeStateUpdate(vector: svAfter1);

        // Fresh peer that never received e1: applying delta creates a Skip for e1's clock range
        // and processes the deletion of e1 in the delete set.
        final peer = await CanvasCrdtAdapter.create();
        expect(() => peer.applyUpdate(delta), returnsNormally);
        final elements = peer.materializeElements();
        expect(elements.containsKey('e1'), isFalse);
        expect(elements.containsKey('e2'), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
