import 'package:flutter/material.dart';

import '../view/trays/canvas_shape_type.dart';

sealed class CanvasElement {
  final String id;
  final int z;

  const CanvasElement({required this.id, required this.z});

  Map<String, dynamic> toMap();

  static CanvasElement fromMap(String id, Map<String, dynamic> data) {
    final type = data['type'] as String;
    final z = data['z'] as int? ?? 0;
    switch (type) {
      case 'stroke':
        return StrokeElement(
          id: id,
          z: z,
          color: Color(data['color'] as int),
          strokeWidth: (data['strokeWidth'] as num).toDouble(),
          opacity: (data['opacity'] as num).toDouble(),
          brushType: data['brushType'] as String? ?? 'solid',
          points: (data['points'] as List<dynamic>?)
                  ?.map((p) => Offset(
                        (p['x'] as num).toDouble(),
                        (p['y'] as num).toDouble(),
                      ))
                  .toList() ??
              [],
        );
      case 'shape':
        return ShapeElement(
          id: id,
          z: z,
          shapeType: CanvasShapeType.values.byName(data['shapeType'] as String),
          center: Offset(
            (data['cx'] as num).toDouble(),
            (data['cy'] as num).toDouble(),
          ),
          size: (data['size'] as num).toDouble(),
          color: Color(data['color'] as int),
          strokeWidth: (data['strokeWidth'] as num).toDouble(),
          isFilled: data['isFilled'] as bool? ?? false,
          rotation: (data['rotation'] as num?)?.toDouble() ?? 0,
          borderRadius:
              (data['borderRadius'] as num?)?.toDouble() ?? 0,
        );
      case 'text':
        return TextElement(
          id: id,
          z: z,
          text: data['text'] as String? ?? '',
          center: Offset(
            (data['cx'] as num).toDouble(),
            (data['cy'] as num).toDouble(),
          ),
          color: Color(data['color'] as int),
        );
      case 'image':
        return ImageElement(
          id: id,
          z: z,
          center: Offset(
            (data['cx'] as num).toDouble(),
            (data['cy'] as num).toDouble(),
          ),
          width: (data['width'] as num).toDouble(),
          height: (data['height'] as num).toDouble(),
          imageBase64: data['imageBase64'] as String? ?? '',
        );
      default:
        throw ArgumentError('Unknown canvas element type: $type');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasElement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          z == other.z;

  @override
  int get hashCode => id.hashCode ^ z.hashCode;
}

class StrokeElement extends CanvasElement {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final String brushType;

  const StrokeElement({
    required super.id,
    required super.z,
    this.points = const [],
    required this.color,
    this.strokeWidth = 5,
    this.opacity = 1.0,
    this.brushType = 'solid',
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'stroke',
        'z': z,
        'color': color.value,
        'strokeWidth': strokeWidth,
        'opacity': opacity,
        'brushType': brushType,
        'points': points
            .map((p) => {'x': p.dx, 'y': p.dy})
            .toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrokeElement &&
          super == other &&
          color == other.color &&
          strokeWidth == other.strokeWidth &&
          opacity == other.opacity &&
          brushType == other.brushType &&
          _listEquals(points, other.points);

  @override
  int get hashCode =>
      super.hashCode ^
      color.hashCode ^
      strokeWidth.hashCode ^
      opacity.hashCode ^
      brushType.hashCode ^
      Object.hashAll(points);

  static bool _listEquals(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class ShapeElement extends CanvasElement {
  final CanvasShapeType shapeType;
  final Offset center;
  final double size;
  final Color color;
  final double strokeWidth;
  final bool isFilled;
  final double rotation;
  final double borderRadius;

  const ShapeElement({
    required super.id,
    required super.z,
    required this.shapeType,
    required this.center,
    required this.size,
    required this.color,
    this.strokeWidth = 2,
    this.isFilled = false,
    this.rotation = 0,
    this.borderRadius = 0,
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'shape',
        'z': z,
        'shapeType': shapeType.name,
        'cx': center.dx,
        'cy': center.dy,
        'size': size,
        'color': color.value,
        'strokeWidth': strokeWidth,
        'isFilled': isFilled,
        'rotation': rotation,
        'borderRadius': borderRadius,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShapeElement &&
          super == other &&
          shapeType == other.shapeType &&
          center == other.center &&
          size == other.size &&
          color == other.color &&
          strokeWidth == other.strokeWidth &&
          isFilled == other.isFilled &&
          rotation == other.rotation &&
          borderRadius == other.borderRadius;

  @override
  int get hashCode =>
      super.hashCode ^
      shapeType.hashCode ^
      center.hashCode ^
      size.hashCode ^
      color.hashCode ^
      strokeWidth.hashCode ^
      isFilled.hashCode ^
      rotation.hashCode ^
      borderRadius.hashCode;
}

class TextElement extends CanvasElement {
  final String text;
  final Offset center;
  final Color color;

  const TextElement({
    required super.id,
    required super.z,
    this.text = '',
    required this.center,
    required this.color,
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'text',
        'z': z,
        'text': text,
        'cx': center.dx,
        'cy': center.dy,
        'color': color.value,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextElement &&
          super == other &&
          text == other.text &&
          center == other.center &&
          color == other.color;

  @override
  int get hashCode =>
      super.hashCode ^ text.hashCode ^ center.hashCode ^ color.hashCode;
}

class ImageElement extends CanvasElement {
  final Offset center;
  final double width;
  final double height;
  final String imageBase64;

  const ImageElement({
    required super.id,
    required super.z,
    required this.center,
    this.width = 100,
    this.height = 100,
    this.imageBase64 = '',
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'image',
        'z': z,
        'cx': center.dx,
        'cy': center.dy,
        'width': width,
        'height': height,
        'imageBase64': imageBase64,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageElement &&
          super == other &&
          center == other.center &&
          width == other.width &&
          height == other.height &&
          imageBase64 == other.imageBase64;

  @override
  int get hashCode =>
      super.hashCode ^
      center.hashCode ^
      width.hashCode ^
      height.hashCode ^
      imageBase64.hashCode;
}
