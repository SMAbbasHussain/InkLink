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

      test('toMap / fromMap round-trip with brushId, pressures, spacing, and textureSeed', () {
        final original = StrokeElement(
          id: 'stroke-advanced',
          z: 2,
          points: const [Offset(10, 20), Offset(30, 40)],
          color: Colors.green,
          strokeWidth: 5,
          opacity: 0.9,
          brushType: 'charcoal',
          brushId: 'charcoal',
          pressures: const [0.4, 0.9],
          spacing: 0.35,
          textureSeed: 777,
        );

        final map = original.toMap();
        final restored = CanvasElement.fromMap(original.id, map) as StrokeElement;

        expect(restored.id, original.id);
        expect(restored.brushId, 'charcoal');
        expect(restored.pressures, [0.4, 0.9]);
        expect(restored.spacing, 0.35);
        expect(restored.textureSeed, 777);
      });

      test('fromMap backward compatibility for legacy strokes without pressures or brushId', () {
        final legacyMap = <String, dynamic>{
          'type': 'stroke',
          'points': [
            {'x': 5.0, 'y': 10.0},
            {'x': 15.0, 'y': 25.0},
          ],
          'color': Colors.black.value,
          'strokeWidth': 4.0,
          'brushType': 'marker',
        };

        final restored = CanvasElement.fromMap('legacy-1', legacyMap) as StrokeElement;
        expect(restored.brushType, 'marker');
        expect(restored.brushId, 'marker');
        expect(restored.pressures, isEmpty);
        expect(restored.spacing, 0.25);
        expect(restored.textureSeed, 0);
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

      test('legacy shape payload defaults the F-10 fields', () {
        final legacy = CanvasElement.fromMap('old-shape', {
          'type': 'shape',
          'shapeType': 'rectangle',
          'cx': 10.0,
          'cy': 20.0,
          'size': 50.0,
          'color': Colors.black.value,
          'strokeWidth': 2.0,
        }) as ShapeElement;

        expect(legacy.width, 0);
        expect(legacy.height, 0);
        expect(legacy.strokeOpacity, 1.0);
        expect(legacy.dashPattern, isNull);
        expect(legacy.label, '');
        expect(legacy.labelColor, isNull);
        expect(legacy.labelFontSize, 14);
        expect(legacy.labelFontWeight, 600);
        expect(legacy.labelTextAlign, 'center');
        expect(legacy.startArrowhead, isFalse);
        expect(legacy.endArrowhead, isFalse);
      });

      test('legacy arrow keeps its end arrowhead', () {
        final legacy = CanvasElement.fromMap('old-arrow', {
          'type': 'shape',
          'shapeType': 'arrow',
          'cx': 0.0,
          'cy': 0.0,
          'size': 50.0,
          'color': Colors.black.value,
          'strokeWidth': 2.0,
        }) as ShapeElement;

        expect(legacy.endArrowhead, isTrue);
        expect(legacy.startArrowhead, isFalse);
      });

      test('round-trips width/height, label, stroke opacity, dash, arrowheads',
          () {
        const original = ShapeElement(
          id: 'shape-f10',
          z: 1,
          shapeType: CanvasShapeType.rectangle,
          center: Offset(100, 100),
          size: 200,
          width: 200,
          height: 80,
          color: Color(0xFF2196F3),
          strokeWidth: 3,
          strokeOpacity: 0.5,
          dashPattern: [12, 8],
          isFilled: true,
          label: 'Hello',
          labelColor: Color(0xFFF44336),
          labelFontSize: 20,
          labelFontWeight: 700,
          labelTextAlign: 'left',
          startArrowhead: true,
          endArrowhead: true,
        );

        final restored =
            CanvasElement.fromMap(original.id, original.toMap()) as ShapeElement;

        expect(restored, original);
        expect(restored.width, 200);
        expect(restored.height, 80);
        expect(restored.strokeOpacity, 0.5);
        expect(restored.dashPattern, [12, 8]);
        expect(restored.label, 'Hello');
        expect(restored.labelColor, const Color(0xFFF44336));
        expect(restored.labelFontSize, 20);
        expect(restored.labelFontWeight, 700);
        expect(restored.labelTextAlign, 'left');
        expect(restored.startArrowhead, isTrue);
        expect(restored.endArrowhead, isTrue);
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

    group('StickyNoteElement', () {
      test('toMap / fromMap round-trip', () {
        final original = StickyNoteElement(
          id: 'note-1',
          z: 5,
          center: const Offset(150, 250),
          width: 180,
          height: 180,
          text: 'Sprint planning idea',
          color: const Color(0xFFFFF9A6),
          rotation: 0.1,
        );

        final map = original.toMap();
        final restored = CanvasElement.fromMap(original.id, map);

        expect(restored, isA<StickyNoteElement>());
        final note = restored as StickyNoteElement;
        expect(note.id, original.id);
        expect(note.z, original.z);
        expect(note.center, original.center);
        expect(note.width, original.width);
        expect(note.height, original.height);
        expect(note.text, original.text);
        expect(note.color.value, original.color.value);
        expect(note.rotation, original.rotation);
      });

      test('equality and hashCode', () {
        final a = StickyNoteElement(
          id: 'note-1',
          z: 2,
          center: const Offset(10, 20),
          text: 'Hello',
        );
        final b = StickyNoteElement(
          id: 'note-1',
          z: 2,
          center: const Offset(10, 20),
          text: 'Hello',
        );
        final c = StickyNoteElement(
          id: 'note-2',
          z: 2,
          center: const Offset(10, 20),
          text: 'Hello',
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(a, isNot(equals(c)));
      });
    });

    group('ConnectorElement', () {
      test('toMap / fromMap round-trip', () {
        final original = ConnectorElement(
          id: 'conn-1',
          z: 3,
          startElementId: 'shape-1',
          startPoint: const Offset(50, 50),
          startAnchor: 'right',
          endElementId: 'shape-2',
          endPoint: const Offset(200, 200),
          endAnchor: 'left',
          lineStyle: 'orthogonal',
          color: const Color(0xFF1E293B),
          strokeWidth: 3.0,
          hasArrowhead: true,
        );

        final map = original.toMap();
        final restored = CanvasElement.fromMap(original.id, map);

        expect(restored, isA<ConnectorElement>());
        final conn = restored as ConnectorElement;
        expect(conn.id, original.id);
        expect(conn.z, original.z);
        expect(conn.startElementId, original.startElementId);
        expect(conn.startPoint, original.startPoint);
        expect(conn.startAnchor, original.startAnchor);
        expect(conn.endElementId, original.endElementId);
        expect(conn.endPoint, original.endPoint);
        expect(conn.endAnchor, original.endAnchor);
        expect(conn.lineStyle, original.lineStyle);
        expect(conn.color.value, original.color.value);
        expect(conn.strokeWidth, original.strokeWidth);
        expect(conn.hasArrowhead, original.hasArrowhead);
      });

      test('equality and hashCode', () {
        final a = ConnectorElement(
          id: 'conn-1',
          z: 1,
          startPoint: const Offset(10, 10),
          endPoint: const Offset(100, 100),
        );
        final b = ConnectorElement(
          id: 'conn-1',
          z: 1,
          startPoint: const Offset(10, 10),
          endPoint: const Offset(100, 100),
        );
        final c = ConnectorElement(
          id: 'conn-1',
          z: 1,
          startPoint: const Offset(20, 20),
          endPoint: const Offset(100, 100),
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(a, isNot(equals(c)));
      });

      test('legacy connector payload defaults the F-11 fields', () {
        final restored = CanvasElement.fromMap('conn-legacy', const {
          'type': 'connector',
          'z': 0,
          'sx': 0.0,
          'sy': 0.0,
          'ex': 100.0,
          'ey': 0.0,
        }) as ConnectorElement;

        expect(restored.startArrowhead, isFalse);
        expect(restored.endArrowhead, isTrue);
        expect(restored.hasArrowhead, isTrue);
        expect(restored.cornerRadius, 0);
        expect(restored.dashPattern, isNull);
        expect(restored.label, '');
        expect(restored.labelColor, isNull);
        expect(restored.labelFontSize, 14);
      });

      test('legacy hasArrowhead maps to endArrowhead on read', () {
        final off = CanvasElement.fromMap('conn-off', const {
          'type': 'connector',
          'z': 0,
          'sx': 0.0,
          'sy': 0.0,
          'ex': 10.0,
          'ey': 0.0,
          'hasArrowhead': false,
        }) as ConnectorElement;
        expect(off.endArrowhead, isFalse);
        expect(off.hasArrowhead, isFalse);

        // The explicit endArrowhead key wins over the legacy flag.
        final overridden = CanvasElement.fromMap('conn-over', const {
          'type': 'connector',
          'z': 0,
          'sx': 0.0,
          'sy': 0.0,
          'ex': 10.0,
          'ey': 0.0,
          'hasArrowhead': true,
          'endArrowhead': false,
        }) as ConnectorElement;
        expect(overridden.endArrowhead, isFalse);
      });

      test('round-trips label, arrowheads, dash and corner radius', () {
        final original = ConnectorElement(
          id: 'conn-rich',
          z: 2,
          startPoint: const Offset(0, 0),
          endPoint: const Offset(120, 80),
          lineStyle: 'orthogonal',
          color: const Color(0xFF2563EB),
          strokeWidth: 4,
          hasArrowhead: true,
          startArrowhead: true,
          cornerRadius: 12,
          dashPattern: const [12, 8],
          label: 'depends on',
          labelColor: const Color(0xFFF44336),
          labelFontSize: 18,
        );

        final map = original.toMap();
        // Both the legacy and the new end-arrow keys are written for compat.
        expect(map['hasArrowhead'], isTrue);
        expect(map['endArrowhead'], isTrue);
        final restored =
            CanvasElement.fromMap(original.id, map) as ConnectorElement;

        expect(restored, original);
        expect(restored.startArrowhead, isTrue);
        expect(restored.endArrowhead, isTrue);
        expect(restored.cornerRadius, 12);
        expect(restored.dashPattern, const [12, 8]);
        expect(restored.label, 'depends on');
        expect(restored.labelColor, const Color(0xFFF44336));
        expect(restored.labelFontSize, 18);
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
          StickyNoteElement(id: 'sn', z: 0, center: Offset.zero),
          ConnectorElement(id: 'cn', z: 0, startPoint: Offset.zero, endPoint: const Offset(10, 10)),
        ];

        final types = elements.map((e) => switch (e) {
          StrokeElement _ => 'stroke',
          ShapeElement _ => 'shape',
          TextElement _ => 'text',
          ImageElement _ => 'image',
          StickyNoteElement _ => 'sticky_note',
          ConnectorElement _ => 'connector',
          LayerElement _ => 'layer',
        });

        expect(types, containsAll(['stroke', 'shape', 'text', 'image', 'sticky_note', 'connector']));
      });

      test('is checks work correctly', () {
        final stroke = StrokeElement(id: 's', z: 0, points: [], color: Colors.black);
        final shape = ShapeElement(
          id: 'sh', z: 0, shapeType: CanvasShapeType.square,
          center: Offset.zero, size: 10, color: Colors.black,
        );
        final text = TextElement(id: 't', z: 0, text: '', center: Offset.zero, color: Colors.black);
        final image = ImageElement(id: 'i', z: 0, center: Offset.zero, imageBase64: '');
        final sticky = StickyNoteElement(id: 'sn', z: 0, center: Offset.zero);
        final connector = ConnectorElement(id: 'cn', z: 0, startPoint: Offset.zero, endPoint: const Offset(10, 10));

        expect(stroke is StrokeElement, isTrue);
        expect(stroke is CanvasElement, isTrue);
        expect(shape is ShapeElement, isTrue);
        expect(text is TextElement, isTrue);
        expect(image is ImageElement, isTrue);
        expect(sticky is StickyNoteElement, isTrue);
        expect(connector is ConnectorElement, isTrue);
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

    group('image transform metadata', () {
      test('round-trips rotation and flip through the payload', () {
        const image = ImageElement(
          id: 'img',
          z: 2,
          center: Offset(10, 20),
          width: 40,
          height: 30,
          imageBase64: '',
          rotation: 0.75,
          flipped: true,
        );

        final restored = CanvasElement.fromMap('img', image.toMap());

        expect(restored, image);
        final typed = restored as ImageElement;
        expect(typed.rotation, 0.75);
        expect(typed.flipped, isTrue);
      });

      test('legacy image payloads default to upright and unflipped', () {
        final element = CanvasElement.fromMap('old', {
          'type': 'image',
          'z': 0,
          'cx': 0.0,
          'cy': 0.0,
          'width': 10.0,
          'height': 10.0,
          'imageBase64': '',
        }) as ImageElement;

        expect(element.rotation, 0);
        expect(element.flipped, isFalse);
      });
    });
  });
}
