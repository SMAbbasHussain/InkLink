import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';

/// The exact map an image element produced BEFORE the optional AI fields
/// existed. Old boards contain this shape.
Map<String, dynamic> _legacyImageMap() => {
  'type': 'image',
  'z': 3,
  'cx': 120.5,
  'cy': -40.0,
  'width': 280.0,
  'height': 160.0,
  'imageBase64': 'aW5saW5lLWJ5dGVz',
};

const _url = 'https://cdn.example.test/ai-images/board1/gen1.png';

void _grantEditor(CanvasBloc bloc) {
  bloc.add(const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor));
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('ImageElement backward compatibility', () {
    test('a legacy element parses with no AI fields', () {
      final element = CanvasElement.fromMap('img1', _legacyImageMap()) as ImageElement;

      expect(element.id, 'img1');
      expect(element.z, 3);
      expect(element.center, const Offset(120.5, -40.0));
      expect(element.width, 280.0);
      expect(element.height, 160.0);
      expect(element.imageBase64, 'aW5saW5lLWJ5dGVz');
      expect(element.imageUrl, isNull);
      expect(element.aiPrompt, isNull);
      expect(element.generationId, isNull);
      expect(element.isAiImage, isFalse);
    });

    test('a legacy element round-trips its fields without AI keys', () {
      final legacy = _legacyImageMap();
      final roundTripped = CanvasElement.fromMap('img1', legacy).toMap();

      for (final entry in legacy.entries) {
        expect(roundTripped[entry.key], entry.value);
      }
      for (final key in ImageElement.aiFieldKeys) {
        expect(roundTripped.containsKey(key), isFalse, reason: key);
      }
    });

    test('an image built without AI fields writes none of them', () {
      const element = ImageElement(id: 'a', z: 0, center: Offset(1, 2), imageBase64: 'eA==');
      final map = element.toMap();

      for (final key in ImageElement.aiFieldKeys) {
        expect(map.containsKey(key), isFalse, reason: key);
      }
      expect(map['type'], 'image');
      expect(map['z'], 0);
      expect(map['cx'], 1.0);
      expect(map['cy'], 2.0);
      expect(map['imageBase64'], 'eA==');
    });

    test('an AI element round-trips all fields', () {
      const element = ImageElement(
        id: 'ai1',
        z: 7,
        center: Offset(10, 20),
        width: 320,
        height: 180,
        imageBase64: 'dGh1bWI=',
        imageUrl: _url,
        aiPrompt: 'a red fox',
        generationId: 'gen1',
      );

      final map = element.toMap();
      expect(map['imageUrl'], _url);
      expect(map['aiPrompt'], 'a red fox');
      expect(map['generationId'], 'gen1');
      expect(map['imageBase64'], 'dGh1bWI=');

      final parsed = CanvasElement.fromMap('ai1', map) as ImageElement;
      expect(parsed, element);
      expect(parsed.hashCode, element.hashCode);
      expect(parsed.isAiImage, isTrue);
    });

    test('equality distinguishes images that differ only in AI fields', () {
      const plain = ImageElement(id: 'a', z: 0, center: Offset.zero, imageBase64: 'eA==');
      const ai = ImageElement(
        id: 'a',
        z: 0,
        center: Offset.zero,
        imageBase64: 'eA==',
        imageUrl: _url,
      );
      expect(plain == ai, isFalse);
    });

    test('missing, null, empty or wrongly typed AI fields never crash', () {
      final variants = <Map<String, dynamic>>[
        {..._legacyImageMap(), 'imageUrl': null, 'aiPrompt': null, 'generationId': null},
        {..._legacyImageMap(), 'imageUrl': '', 'aiPrompt': '   ', 'generationId': ''},
        {..._legacyImageMap(), 'imageUrl': 42, 'aiPrompt': ['x'], 'generationId': {'a': 1}},
        {..._legacyImageMap(), 'imageUrl': true},
      ];
      for (final data in variants) {
        final element = CanvasElement.fromMap('img1', data) as ImageElement;
        expect(element.imageUrl, isNull, reason: '$data');
        expect(element.aiPrompt, isNull);
        expect(element.generationId, isNull);
        expect(element.imageBase64, 'aW5saW5lLWJ5dGVz');
        // And it serialises back without any AI keys.
        final map = element.toMap();
        for (final key in ImageElement.aiFieldKeys) {
          expect(map.containsKey(key), isFalse, reason: key);
        }
      }
    });

    test('unknown extra fields from a newer app version are ignored', () {
      final data = {
        ..._legacyImageMap(),
        'imageUrl': _url,
        'someFutureField': {'nested': true},
        'rotation': 1.5,
      };
      final element = CanvasElement.fromMap('img1', data) as ImageElement;
      expect(element.imageUrl, _url);
      expect(element.width, 280.0);
    });

    test('an AI element without a thumbnail still parses (empty inline image)', () {
      final data = {..._legacyImageMap(), 'imageUrl': _url}..remove('imageBase64');
      final element = CanvasElement.fromMap('img1', data) as ImageElement;
      expect(element.imageBase64, '');
      expect(element.imageUrl, _url);
    });

    test('other element types are unaffected', () {
      final shape = {
        'type': 'shape',
        'z': 1,
        'shapeType': 'circle',
        'cx': 1.0,
        'cy': 2.0,
        'size': 64.0,
        'color': 0xFF000000,
        'strokeWidth': 2.0,
        'isFilled': false,
        'rotation': 0.0,
        'borderRadius': 0.0,
      };
      final roundTripped = CanvasElement.fromMap('s1', shape).toMap();
      for (final entry in shape.entries) {
        expect(roundTripped[entry.key], entry.value);
      }
      for (final key in ImageElement.aiFieldKeys) {
        expect(roundTripped.containsKey(key), isFalse, reason: key);
      }
    });
  });

  group('CRDT adapter carries the AI fields', () {
    test('legacy and AI elements survive a full state transfer unchanged', () async {
      final source = await CanvasCrdtAdapter.create();
      const ai = ImageElement(
        id: 'ai1',
        z: 2,
        center: Offset(5, 6),
        width: 300,
        height: 300,
        imageBase64: 'dGh1bWI=',
        imageUrl: _url,
        aiPrompt: 'a red fox',
        generationId: 'gen1',
      );
      source.upsertElement('legacy', _legacyImageMap());
      source.upsertElement('ai1', ai.toMap());

      final target = await CanvasCrdtAdapter.create();
      target.applyUpdate(source.encodeStateUpdate());
      final materialized = target.materializeElements();

      final parsedLegacy =
          CanvasElement.fromMap('legacy', materialized['legacy']!) as ImageElement;
      expect(parsedLegacy.center, const Offset(120.5, -40.0));
      expect(parsedLegacy.width, 280.0);
      expect(parsedLegacy.height, 160.0);
      expect(parsedLegacy.imageBase64, 'aW5saW5lLWJ5dGVz');
      expect(materialized['legacy']!.containsKey('imageUrl'), isFalse);
      expect(CanvasElement.fromMap('ai1', materialized['ai1']!), ai);
    });

    test('replacing the source is one update and one undo restores the old version', () async {
      final adapter = await CanvasCrdtAdapter.create();
      const before = ImageElement(
        id: 'ai1',
        z: 2,
        center: Offset(5, 6),
        imageBase64: 'b2xk',
        imageUrl: _url,
        aiPrompt: 'a red fox',
        generationId: 'gen1',
      );
      adapter.upsertElement('ai1', before.toMap());
      // Yjs groups changes made within a short window into one undo step.
      await Future<void>.delayed(const Duration(milliseconds: 700));

      const after = ImageElement(
        id: 'ai1',
        z: 2,
        center: Offset(5, 6),
        imageBase64: 'bmV3',
        imageUrl: 'https://cdn.example.test/ai-images/board1/gen2.png',
        aiPrompt: 'a red fox at night',
        generationId: 'gen2',
      );
      final update = adapter.upsertElement('ai1', after.toMap());
      expect(update, isNotEmpty);
      expect(CanvasElement.fromMap('ai1', adapter.materializeElements()['ai1']!), after);

      final undo = adapter.undoLast();
      expect(undo, isNotNull);
      expect(CanvasElement.fromMap('ai1', adapter.materializeElements()['ai1']!), before);

      final redo = adapter.redoLast();
      expect(redo, isNotNull);
      expect(CanvasElement.fromMap('ai1', adapter.materializeElements()['ai1']!), after);
    });
  });

  group('CanvasBloc AI image events', () {
    test('CanvasAddAiImageElement adds a URL image with the thumbnail inline', () async {
      final bloc = CanvasBloc();
      _grantEditor(bloc);
      bloc.add(
        const CanvasAddAiImageElement(
          imageUrl: _url,
          thumbnailBase64: 'dGh1bWI=',
          center: Offset(100, 200),
          width: 280,
          height: 157.5,
          aiPrompt: 'a red fox',
          generationId: 'gen1',
        ),
      );
      await _settle();

      final image = bloc.state.elements.single as ImageElement;
      expect(image.imageUrl, _url);
      expect(image.imageBase64, 'dGh1bWI=');
      expect(image.aiPrompt, 'a red fox');
      expect(image.generationId, 'gen1');
      expect(image.center, const Offset(100, 200));
      expect(image.width, 280);
      expect(image.height, 157.5);
      await bloc.close();
    });

    test('viewers cannot add or replace AI images', () async {
      final bloc = CanvasBloc(); // default role is viewer
      bloc.add(
        const CanvasAddAiImageElement(
          imageUrl: _url,
          thumbnailBase64: 'dGh1bWI=',
          center: Offset.zero,
          width: 200,
          height: 200,
        ),
      );
      await _settle();
      expect(bloc.state.elements, isEmpty);
      await bloc.close();
    });

    test('moving or resizing an AI image keeps its AI fields', () async {
      final bloc = CanvasBloc();
      _grantEditor(bloc);
      bloc.add(
        const CanvasAddAiImageElement(
          imageUrl: _url,
          thumbnailBase64: 'dGh1bWI=',
          center: Offset(100, 100),
          width: 200,
          height: 200,
          aiPrompt: 'a red fox',
          generationId: 'gen1',
        ),
      );
      await _settle();
      final id = bloc.state.elements.single.id;

      bloc.add(
        CanvasUpdateImageElement(
          elementId: id,
          center: const Offset(300, 250),
          width: 400,
          height: 300,
        ),
      );
      await _settle();

      final moved = bloc.state.elements.single as ImageElement;
      expect(moved.center, const Offset(300, 250));
      expect(moved.width, 400);
      expect(moved.height, 300);
      expect(moved.imageUrl, _url);
      expect(moved.aiPrompt, 'a red fox');
      expect(moved.generationId, 'gen1');
      expect(moved.imageBase64, 'dGh1bWI=');

      bloc.add(CanvasSelectShape(id));
      await _settle();
      bloc.add(const CanvasMoveSelectedShape(Offset(10, 20)));
      await _settle();

      final movedAgain = bloc.state.elements.single as ImageElement;
      expect(movedAgain.center, const Offset(10, 20));
      expect(movedAgain.imageUrl, _url);
      expect(movedAgain.aiPrompt, 'a red fox');
      expect(movedAgain.generationId, 'gen1');
      await bloc.close();
    });

    test('moving an ordinary inline image adds no AI fields', () async {
      final bloc = CanvasBloc();
      _grantEditor(bloc);
      bloc.add(
        CanvasAddImageElement(
          Uint8List.fromList([1, 2, 3]),
          const Offset(50, 50),
          width: 200,
          height: 200,
        ),
      );
      await _settle();
      final id = bloc.state.elements.single.id;
      bloc.add(
        CanvasUpdateImageElement(
          elementId: id,
          center: const Offset(90, 90),
          width: 220,
          height: 220,
        ),
      );
      await _settle();

      final image = bloc.state.elements.single as ImageElement;
      expect(image.imageUrl, isNull);
      expect(image.aiPrompt, isNull);
      expect(image.generationId, isNull);
      expect(image.imageBase64, base64Encode([1, 2, 3]));
      expect(image.toMap().keys, isNot(contains('imageUrl')));
      await bloc.close();
    });

    test('CanvasReplaceImageSource swaps the picture and keeps position and z', () async {
      final bloc = CanvasBloc();
      _grantEditor(bloc);
      bloc.add(
        const CanvasAddAiImageElement(
          imageUrl: _url,
          thumbnailBase64: 'b2xk',
          center: Offset(100, 100),
          width: 280,
          height: 280,
          aiPrompt: 'a red fox',
          generationId: 'gen1',
        ),
      );
      await _settle();
      final before = bloc.state.elements.single as ImageElement;

      bloc.add(
        CanvasReplaceImageSource(
          elementId: before.id,
          imageUrl: 'https://cdn.example.test/ai-images/board1/gen2.png',
          thumbnailBase64: 'bmV3',
          sourceWidth: 1280,
          sourceHeight: 720,
          aiPrompt: 'a red fox at night',
          generationId: 'gen2',
        ),
      );
      await _settle();

      final after = bloc.state.elements.single as ImageElement;
      expect(after.id, before.id);
      expect(after.z, before.z);
      expect(after.center, before.center);
      expect(after.imageUrl, 'https://cdn.example.test/ai-images/board1/gen2.png');
      expect(after.imageBase64, 'bmV3');
      expect(after.aiPrompt, 'a red fox at night');
      expect(after.generationId, 'gen2');
      // Longest side kept, new 16:9 aspect ratio followed.
      expect(after.width, 280);
      expect(after.height, closeTo(157.5, 0.001));
      await bloc.close();
    });

    test('CanvasReplaceImageSource keeps the old prompt when none is given', () async {
      final bloc = CanvasBloc();
      _grantEditor(bloc);
      bloc.add(
        const CanvasAddAiImageElement(
          imageUrl: _url,
          thumbnailBase64: 'b2xk',
          center: Offset.zero,
          width: 200,
          height: 200,
          aiPrompt: 'a red fox',
        ),
      );
      await _settle();
      final id = bloc.state.elements.single.id;
      bloc.add(
        CanvasReplaceImageSource(
          elementId: id,
          imageUrl: 'https://cdn.example.test/ai-images/board1/gen2.png',
          thumbnailBase64: 'bmV3',
          sourceWidth: 1024,
          sourceHeight: 1024,
        ),
      );
      await _settle();
      expect((bloc.state.elements.single as ImageElement).aiPrompt, 'a red fox');
      await bloc.close();
    });

    test('CanvasReplaceImageSource does nothing when the image was deleted', () async {
      final bloc = CanvasBloc();
      _grantEditor(bloc);
      bloc.add(
        const CanvasReplaceImageSource(
          elementId: 'missing',
          imageUrl: _url,
          thumbnailBase64: 'bmV3',
          sourceWidth: 100,
          sourceHeight: 100,
        ),
      );
      await _settle();
      expect(bloc.state.elements, isEmpty);
      await bloc.close();
    });
  });
}
