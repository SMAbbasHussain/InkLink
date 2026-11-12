import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';

/// yjs merges edits made within `captureTimeout` into one undo entry, so
/// discrete user actions in these tests are separated in time on purpose.
Future<void> _separateEdits() =>
    Future<void>.delayed(const Duration(milliseconds: 550));

Map<String, dynamic> _stroke(String id) => {
  'type': 'stroke',
  'z': 1,
  'color': 0xFF000000,
  'strokeWidth': 4.0,
  'opacity': 1.0,
  'brushType': 'solid',
  'points': [
    {'x': 0.0, 'y': 0.0},
    {'x': 8.0, 'y': 8.0},
  ],
  'label': id,
};

void main() {
  group('local undo ledger (D2/D14)', () {
    test('undo then redo restores exactly the same element', () async {
      final adapter = await CanvasCrdtAdapter.create();
      adapter.upsertElement('a', _stroke('a'));
      expect(adapter.materializeElements().containsKey('a'), isTrue);

      final undo = adapter.undoLast();
      expect(undo, isNotNull);
      expect(adapter.materializeElements().containsKey('a'), isFalse);

      final redo = adapter.redoLast();
      expect(redo, isNotNull);
      final restored = adapter.materializeElements()['a']!;
      expect(restored['type'], 'stroke');
      expect((restored['points'] as List).length, 2);
    });

    test('redo with an empty redo stack is a no-op', () async {
      final adapter = await CanvasCrdtAdapter.create();
      expect(adapter.redoLast(), isNull);
    });

    test('undo of a delete brings the element back', () async {
      final adapter = await CanvasCrdtAdapter.create();
      adapter.upsertElement('a', _stroke('a'));
      await _separateEdits();
      adapter.deleteElement('a');
      expect(adapter.materializeElements(), isEmpty);

      adapter.undoLast();
      expect(adapter.materializeElements().containsKey('a'), isTrue);
    });

    test('a remote owner revert prunes the entries it replaced', () async {
      final adapter = await CanvasCrdtAdapter.create();
      adapter.upsertElement('a', _stroke('a'));
      await _separateEdits();
      adapter.upsertElement('b', _stroke('b'));

      // Owner reverted element 'a' (D14): its local entries must never be
      // undoable again, but 'b' is untouched.
      adapter.pruneReverted({'a'});
      final update = adapter.undoLast();
      expect(update, isNotNull);
      expect(adapter.materializeElements().containsKey('b'), isFalse);
      expect(
        adapter.materializeElements().containsKey('a'),
        isTrue,
        reason: 'pruned entries must not undo the reverted element',
      );
      expect(adapter.undoLast(), isNull);
    });

    test('pruning an unknown element leaves history intact', () async {
      final adapter = await CanvasCrdtAdapter.create();
      adapter.upsertElement('a', _stroke('a'));
      adapter.pruneReverted({'does-not-exist'});
      expect(adapter.undoLast(), isNotNull);
    });

    test('a full restore clears the local history', () async {
      final adapter = await CanvasCrdtAdapter.create();
      adapter.upsertElement('a', _stroke('a'));
      adapter.clearLocalHistory();
      expect(adapter.undoLast(), isNull);
      expect(adapter.materializeElements().containsKey('a'), isTrue);
    });

    test('remote updates never enter the local undo stack', () async {
      final author = await CanvasCrdtAdapter.create();
      final peer = await CanvasCrdtAdapter.create();
      peer.applyUpdate(author.upsertElement('a', _stroke('a')));

      expect(peer.undoLast(), isNull);
      expect(peer.materializeElements().containsKey('a'), isTrue);
    });
  });
}
