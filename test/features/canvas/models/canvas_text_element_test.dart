import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';

void main() {
  group('TextElement', () {
    test('toMap / fromMap round-trips every style field', () {
      const original = TextElement(
        id: 'text-1',
        z: 4,
        text: 'Hello\nworld',
        center: Offset(24, 48),
        color: Color(0xFF112233),
        width: 180,
        height: 64,
        fontSize: 24,
        fontWeight: 700,
        fontFamily: 'Georgia',
        textAlign: 'center',
        lineHeight: 1.4,
        rotation: 0.75,
        maxLines: 3,
        autoSize: true,
        backgroundColor: Color(0x33FFFF00),
        padding: 6,
      );

      final restored = CanvasElement.fromMap(original.id, original.toMap());

      expect(restored, isA<TextElement>());
      expect(restored, equals(original));
    });

    test('legacy payload without style fields loads with defaults', () {
      final restored = CanvasElement.fromMap('legacy', {
        'type': 'text',
        'z': 2,
        'text': 'Old note',
        'cx': 12.0,
        'cy': 34.0,
        'color': 0xFF000000,
      });

      final text = restored as TextElement;
      expect(text.text, 'Old note');
      expect(text.center, const Offset(12, 34));
      expect(text.width, 0);
      expect(text.height, 0);
      expect(text.fontSize, 16);
      expect(text.fontWeight, 600);
      expect(text.textAlign, 'left');
      expect(text.lineHeight, 1.2);
      expect(text.rotation, 0);
      // Legacy boards were truncated at two lines; text is unlimited now.
      expect(text.maxLines, 0);
      expect(text.backgroundColor, isNull);
      expect(text.padding, 4);
    });

    test('equality includes style fields so state changes are not dropped', () {
      const base = TextElement(
        id: 't',
        z: 1,
        text: 'A',
        center: Offset.zero,
        color: Colors.black,
      );
      final larger = TextElement(
        id: base.id,
        z: base.z,
        text: base.text,
        center: base.center,
        color: base.color,
        fontSize: 32,
      );
      expect(base == larger, isFalse);
      expect(base.hashCode == larger.hashCode, isFalse);
    });
  });
}
