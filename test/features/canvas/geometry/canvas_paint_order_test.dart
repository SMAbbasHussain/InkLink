import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

ShapeElement _shape({
  required String id,
  required int z,
  Color color = const Color(0xFF000000),
}) {
  return ShapeElement(
    id: id,
    z: z,
    shapeType: CanvasShapeType.square,
    center: const Offset(50, 50),
    size: 20,
    color: color,
  );
}

LayerElement _layer({
  required String id,
  required int z,
  required List<String> members,
}) {
  return LayerElement(
    id: id,
    z: z,
    name: id,
    elementIds: members,
  );
}

void main() {
  group('canvasPaintOrder', () {
    test('paints Default bottom-most, then layers as bands', () {
      final elements = <CanvasElement>[
        _shape(id: 'default', z: 99),
        _shape(id: 'low-a', z: 1),
        _shape(id: 'low-b', z: 8),
        _shape(id: 'high-a', z: 0),
        _shape(id: 'high-b', z: 50),
        _layer(id: 'low', z: 0, members: ['low-b', 'low-a']),
        _layer(id: 'high', z: 1, members: ['high-a', 'high-b']),
      ];

      final order = canvasPaintOrder(elements);

      expect(order.bands.map((band) => band.layer?.id), [
        null,
        'low',
        'high',
      ]);
      expect(order.elements.map((element) => element.id), [
        'default',
        'low-a',
        'low-b',
        'high-a',
        'high-b',
      ]);
      // Highest z in a lower band still paints below the higher band.
      expect(order.isInHigherBand('high-a', 'default'), isTrue);
      expect(order.isInHigherBand('default', 'high-a'), isFalse);
    });

    test('deduplicates membership to the lowest layer listing the id', () {
      final elements = <CanvasElement>[
        _shape(id: 'shared', z: 0),
        _layer(id: 'bottom', z: 0, members: ['shared']),
        _layer(id: 'top', z: 1, members: ['shared']),
      ];

      final order = canvasPaintOrder(elements);

      expect(order.bands[1].elements.map((element) => element.id), ['shared']);
      expect(order.bands[2].elements, isEmpty);
      expect(order.bandFor('shared')?.layer?.id, 'bottom');
    });

    test('ignores stale membership ids and missing elements', () {
      final elements = <CanvasElement>[
        const LayerElement(
          id: 'layer',
          z: 0,
          name: 'Layer',
          elementIds: ['deleted-id'],
        ),
        _shape(id: 'visible', z: 0),
      ];

      expect(
        orderedElementsForPaint(elements).map((element) => element.id),
        ['visible'],
      );
    });

    test('hiding a layer hides its members, locking reports their ids', () {
      final elements = <CanvasElement>[
        _shape(id: 'visible', z: 0),
        _shape(id: 'member', z: 0),
        const LayerElement(
          id: 'layer',
          z: 0,
          name: 'Layer',
          hidden: true,
          locked: true,
          elementIds: ['member'],
        ),
      ];

      final order = canvasPaintOrder(elements);

      expect(order.elements.map((element) => element.id), ['visible']);
      expect(orderedElementsForPaint(elements).map((e) => e.id), ['visible']);
      expect(order.lockedElementIds, {'member'});
    });

    test('layer blend and opacity resolve into member paint effects', () {
      final elements = <CanvasElement>[
        _shape(id: 'member', z: 0),
        const LayerElement(
          id: 'layer',
          z: 0,
          name: 'Layer',
          opacity: 0.5,
          blendMode: 'multiply',
          elementIds: ['member'],
        ),
      ];

      final effects = layerPaintEffects(elements);

      expect(effects['member']?.blendMode, 'multiply');
      expect(effects['member']?.opacity, 0.5);
      expect(canvasBlendModeForName('screen'), BlendMode.screen);
    });

    test('topmost lookup follows bands, not global z', () {
      final elements = <CanvasElement>[
        _shape(id: 'default-top-z', z: 999, color: Colors.red),
        _shape(id: 'layer-low-z', z: 0, color: Colors.blue),
        _layer(id: 'layer', z: 0, members: ['layer-low-z']),
      ];

      final topmost = orderedElementsForPaint(elements).last;
      expect(topmost.id, 'layer-low-z');
    });
  });
}
