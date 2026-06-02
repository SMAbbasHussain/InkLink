// ignore_for_file: unnecessary_type_check

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

void main() {
  group('CanvasElement sealed class', () {
    group('StrokeElement', () {
      test('toMap / fromMap round-trip', () {
        final original = StrokeElement(
          id: 'stroke-1',
          z: 5,
          points: [Offset(10, 20), Offset(30, 40), Offset(50, 60)],
          color: Colors.red,
          strokeWidth: 3,
          opacity: 0.8,
          brushType: 'watercolor',
        );

        final map = original.toMap();
        final restored = CanvasElement.fromMap(original.id, map);

        expect(restored, isA<StrokeElement>());
        final restoredStroke = restored as StrokeElement;
        expect(restoredStroke.id, original.id);
        expect(restoredStroke.z, original.z);
        expect(restoredStroke.color.value, original.color.value);
        expect(restoredStroke.strokeWidth, original.strokeWidth);
        expect(restoredStroke.opacity, original.opacity);
        expect(restoredStroke.brushType, original.brushType);
        expect(restoredStroke.points, original.points);
      });

      test('equality', () {
        final a = StrokeElement(
          id: 's1', z: 1, points: [Offset.zero],
          color: Colors.black,
        );
        final b = StrokeElement(
          id: 's1', z: 1, points: [Offset.zero],
          color: Colors.black,
        );
        final c = StrokeElement(
          id: 's2', z: 1, points: [Offset.zero],
          color: Colors.black,
        );

        expect(a, equals(b));
        expect(a, isNot(equals(c)));
      });
    });

    group('ShapeElement', () {
      test('toMap / fromMap round-trip', () {
        final original = ShapeElement(
          id: 'shape-1',
          z: 3,
          shapeType: CanvasShapeType.circle,
          center: Offset(100, 200),
          size: 80,
          color: Colors.blue,
          strokeWidth: 4,
          isFilled: true,
          rotation: 1.57,
          borderRadius: 10,
        );

        final map = original.toMap();
        final restored = CanvasElement.fromMap(original.id, map);

        expect(restored, isA<ShapeElement>());
        final restoredShape = restored as ShapeElement;
        expect(restoredShape.id, original.id);
        expect(restoredShape.z, original.z);
        expect(restoredShape.shapeType, original.shapeType);
        expect(restoredShape.center, original.center);
        expect(restoredShape.size, original.size);
        expect(restoredShape.color.value, original.color.value);
        expect(restoredShape.strokeWidth, original.strokeWidth);
        expect(restoredShape.isFilled, original.isFilled);
        expect(restoredShape.rotation, closeTo(original.rotation, 0.0001));
        expect(restoredShape.borderRadius, original.borderRadius);
      });

      test('equality', () {
        final a = ShapeElement(
          id: 'sh1', z: 1, shapeType: CanvasShapeType.square,
          center: Offset.zero, size: 50, color: Colors.red,
        );
        final b = ShapeElement(
          id: 'sh1', z: 1, shapeType: CanvasShapeType.square,
          center: Offset.zero, size: 50, color: Colors.red,
        );
        final c = ShapeElement(
          id: 'sh1', z: 1, shapeType: CanvasShapeType.circle,
          center: Offset.zero, size: 50, color: Colors.red,
        );

        expect(a, equals(b));
        expect(a, isNot(equals(c)));
      });
    });

    group('TextElement', () {
      test('toMap / fromMap round-trip', () {
        final original = TextElement(
          id: 'text-1',
          z: 2,
          text: 'Hello World',
          center: Offset(150, 250),
          color: Colors.green,
        );

        final map = original.toMap();
        final restored = CanvasElement.fromMap(original.id, map);

        expect(restored, isA<TextElement>());
        final restoredText = restored as TextElement;
        expect(restoredText.id, original.id);
        expect(restoredText.z, original.z);
        expect(restoredText.text, original.text);
        expect(restoredText.center, original.center);
        expect(restoredText.color.value, original.color.value);
      });

      test('empty text round-trip', () {
        final original = TextElement(
          id: 'empty',
          z: 0,
          text: '',
          center: Offset.zero,
          color: Colors.black,
        );

        final map = original.toMap();
        final restored = CanvasElement.fromMap(original.id, map);

        expect(restored, isA<TextElement>());
        expect((restored as TextElement).text, '');
      });
    });

    group('ImageElement', () {
      test('toMap / fromMap round-trip', () {
        final original = ImageElement(
          id: 'img-1',
          z: 10,
          center: Offset(300, 400),
          width: 200,
          height: 150,
          imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAE=',
        );

        final map = original.toMap();
        final restored = CanvasElement.fromMap(original.id, map);

        expect(restored, isA<ImageElement>());
        final restoredImg = restored as ImageElement;
        expect(restoredImg.id, original.id);
        expect(restoredImg.z, original.z);
        expect(restoredImg.center, original.center);
        expect(restoredImg.width, original.width);
        expect(restoredImg.height, original.height);
        expect(restoredImg.imageBase64, original.imageBase64);
      });
    });

    group('sealed class exhaustiveness', () {
      test('all subtypes can be pattern matched', () {
        final elements = <CanvasElement>[
          StrokeElement(id: 's', z: 0, points: [], color: Colors.black),
          ShapeElement(
            id: 'sh', z: 0, shapeType: CanvasShapeType.square,
            center: Offset.zero, size: 10, color: Colors.black,
          ),
          TextElement(id: 't', z: 0, text: '', center: Offset.zero, color: Colors.black),
          ImageElement(id: 'i', z: 0, center: Offset.zero, imageBase64: ''),
        ];

        final types = elements.map((e) => switch (e) {
          StrokeElement _ => 'stroke',
          ShapeElement _ => 'shape',
          TextElement _ => 'text',
          ImageElement _ => 'image',
        });

        expect(types, containsAll(['stroke', 'shape', 'text', 'image']));
      });

      test('is checks work correctly', () {
        final stroke = StrokeElement(id: 's', z: 0, points: [], color: Colors.black);
        final shape = ShapeElement(
          id: 'sh', z: 0, shapeType: CanvasShapeType.square,
          center: Offset.zero, size: 10, color: Colors.black,
        );
        final text = TextElement(id: 't', z: 0, text: '', center: Offset.zero, color: Colors.black);
        final image = ImageElement(id: 'i', z: 0, center: Offset.zero, imageBase64: '');

        expect(stroke is StrokeElement, isTrue);
        expect(stroke is CanvasElement, isTrue);
        expect(shape is ShapeElement, isTrue);
        expect(text is TextElement, isTrue);
        expect(image is ImageElement, isTrue);
        expect(stroke is ShapeElement, isFalse);
      });

      test('z index access works across all subtypes', () {
        final elements = <CanvasElement>[
          StrokeElement(id: 'a', z: 3, points: [], color: Colors.black),
          ShapeElement(
            id: 'b', z: 1, shapeType: CanvasShapeType.square,
            center: Offset.zero, size: 10, color: Colors.black,
          ),
          TextElement(id: 'c', z: 2, text: '', center: Offset.zero, color: Colors.black),
          ImageElement(id: 'd', z: 0, center: Offset.zero, imageBase64: ''),
        ];

        elements.sort((a, b) => a.z.compareTo(b.z));
        expect(elements.map((e) => e.id), equals(['d', 'b', 'c', 'a']));
      });
    });
  });
}
