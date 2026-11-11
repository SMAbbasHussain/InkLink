import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';
import 'package:inklink/features/canvas/view/trays/shapes_tray.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

void main() {
  Widget buildTestWidget({
    required bool isOpen,
    CanvasShapeType? selectedType,
    ValueChanged<CanvasShapeType>? onSelect,
  }) {
    return MaterialApp(
      theme: InkTheme.light(),
      home: Scaffold(
        body: Stack(
          children: [
            ShapesTray(
              isOpen: isOpen,
              selectedType: selectedType,
              onSelectShapeForDrawing: onSelect ?? (_) {},
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('ShapesTray renders SemicircleIcon for semicircle shape type', (tester) async {
    CanvasShapeType? selected;

    await tester.pumpWidget(
      buildTestWidget(
        isOpen: true,
        onSelect: (type) => selected = type,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Semicircle'), findsOneWidget);
    expect(find.byType(SemicircleIcon), findsOneWidget);

    await tester.tap(find.text('Semicircle'));
    await tester.pumpAndSettle();

    expect(selected, equals(CanvasShapeType.semicircle));
  });
}

