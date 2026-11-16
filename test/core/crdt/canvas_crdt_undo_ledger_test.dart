import 'dart:typed_data';

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

  group('undo/redo peek (§7.2 conflict gate)', () {
    test('empty stack peeks null', () async {
      final adapter = await CanvasCrdtAdapter.create();
      expect(adapter.peekUndoElementIds(), isNull);
      expect(adapter.peekRedoElementIds(), isNull);
    });

    test('peek reports the touched element ids without popping', () async {
      final adapter = await CanvasCrdtAdapter.create();
      adapter.upsertElement('a', _stroke('a'));

      final peeked = adapter.peekUndoElementIds();
      expect(peeked, {'a'});

      // The entry must survive the peek so undoLast still works.
      final undo = adapter.undoLast();
      expect(undo, isNotNull);
      expect(adapter.materializeElements().containsKey('a'), isFalse);
      expect(adapter.peekUndoElementIds(), isNull);
      expect(adapter.peekRedoElementIds(), {'a'});
    });

    test('rapid upserts merge into ONE entry; peek sees all ids at once', () async {
      final adapter = await CanvasCrdtAdapter.create();
      // Both upserts land inside the captureTimeout window, so Yjs merges
      // them into a single undo entry covering both elements.
      adapter.upsertElement('a', _stroke('a'));
      adapter.upsertElement('b', _stroke('b'));

      final peeked = adapter.peekUndoElementIds();
      expect(peeked, {'a', 'b'});

      // One undo reverts the whole merged entry and the entry survives the
      // peek untouched.
      final undo = adapter.undoLast();
      expect(undo, isNotNull);
      expect(adapter.materializeElements().keys, isEmpty);
    });

    test('separate entries peek one id at a time', () async {
      final adapter = await CanvasCrdtAdapter.create();
      adapter.upsertElement('a', _stroke('a'));
      await _separateEdits();
      adapter.upsertElement('b', _stroke('b'));

      // The newest entry is on top of the stack.
      expect(adapter.peekUndoElementIds(), {'b'});
      expect(adapter.undoLast(), isNotNull);
      expect(adapter.peekUndoElementIds(), {'a'});
    });
  });

  group('peer overwrite then peer undo (§7.2)', () {
    /// Applies the local edits to a peer, then broadcasts a self-contained
    /// overwrite diff (throwaway + real value travel together, like a real
    /// multi-edit broadcast — a diff referencing items the receiver lacks
    /// makes them VANISH in yjs_dart).
    Future<(Uint8List, CanvasCrdtAdapter)> peerOverwrite(
      CanvasCrdtAdapter me,
      String elementId,
      Map<String, dynamic> overwritePayload,
    ) async {
      final peer = await CanvasCrdtAdapter.create();
      peer.applyUpdate(me.encodeStateUpdate(), origin: 'remote');
      final before = peer.encodeStateVector();
      peer.upsertElement(elementId, const {'type': 'shape', 'throwaway': true});
      peer.upsertElement(elementId, overwritePayload);
      return (peer.encodeStateUpdate(vector: before), peer);
    }

    test(
      'after the peer undoes their overwrite, undoing our CREATION removes '
      'the element and redo restores it',
      () async {
        final me = await CanvasCrdtAdapter.create();
        me.upsertElement('e', _stroke('e'));

        final (overwrite, peer) = await peerOverwrite(
          me,
          'e',
          _stroke('e-peer'),
        );
        me.applyUpdate(overwrite, origin: 'remote');
        expect(me.materializeElements()['e']!['label'], 'e-peer');

        me.applyUpdate(peer.undoLast()!, origin: 'remote');
        expect(me.materializeElements()['e']!['label'], 'e');

        // Our entry's items were tombstoned by the peer; the undo completes
        // as an element-level delete instead of a silent no-op.
        final undo = me.undoLast();
        expect(undo, isNotNull);
        expect(undo, isNotEmpty);
        expect(me.materializeElements().containsKey('e'), isFalse);

        final redo = me.redoLast();
        expect(redo, isNotNull);
        expect(me.materializeElements()['e']!['label'], 'e');

        expect(me.undoLast(), isNotNull);
        expect(me.materializeElements().containsKey('e'), isFalse);
      },
    );

    test(
      'after the peer undoes their overwrite, undoing our EDIT restores the '
      'pre-edit value and redo re-applies it',
      () async {
        final me = await CanvasCrdtAdapter.create();
        me.upsertElement('e', _stroke('e'));
        await _separateEdits();
        me.upsertElement('e', {..._stroke('e'), 'color': 0xFF00FF00});

        final (overwrite, peer) = await peerOverwrite(
          me,
          'e',
          {..._stroke('e'), 'color': 0xFFFF0000},
        );
        me.applyUpdate(overwrite, origin: 'remote');
        expect(me.materializeElements()['e']!['color'], 0xFFFF0000);

        me.applyUpdate(peer.undoLast()!, origin: 'remote');
        // The peer's undo restored the state before THEIR edit: my edit.
        expect(me.materializeElements()['e']!['color'], 0xFF00FF00);

        final undo = me.undoLast();
        expect(undo, isNotNull);
        expect(undo, isNotEmpty);
        expect(me.materializeElements()['e']!['color'], 0xFF000000);

        final redo = me.redoLast();
        expect(redo, isNotNull);
        expect(me.materializeElements()['e']!['color'], 0xFF00FF00);

        expect(me.undoLast(), isNotNull);
        expect(me.materializeElements()['e']!['color'], 0xFF000000);
      },
    );
  });
}
