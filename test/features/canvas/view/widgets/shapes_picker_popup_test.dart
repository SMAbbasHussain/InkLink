import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';
import 'package:inklink/features/canvas/view/widgets/shapes_picker_popup.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  Widget buildTestWidget({
    CanvasShapeType? selectedType,
    ValueChanged<CanvasShapeType>? onSelect,
    VoidCallback? onClose,
  }) {
    return MaterialApp(
      theme: InkTheme.light(),
      home: Scaffold(
        body: Center(
          child: ShapesPickerPopup(
            selectedType: selectedType,
            onSelectShape: onSelect ?? (_) {},
            onClose: onClose ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'ShapesPickerPopup renders shapes including SemicircleIcon and selects cleanly',
    (tester) async {
      CanvasShapeType? selected;
      var closed = false;

      await tester.pumpWidget(
        buildTestWidget(
          selectedType: CanvasShapeType.square,
          onSelect: (type) => selected = type,
          onClose: () => closed = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose a Shape'), findsOneWidget);
      expect(find.text('Square'), findsOneWidget);
      expect(find.text('Semicircle'), findsOneWidget);
      expect(find.byType(SemicircleIcon), findsOneWidget);

      await tester.tap(find.text('Semicircle'));
      await tester.pumpAndSettle();
      expect(selected, equals(CanvasShapeType.semicircle));

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pump();
      expect(closed, isTrue);
    },
  );
}
