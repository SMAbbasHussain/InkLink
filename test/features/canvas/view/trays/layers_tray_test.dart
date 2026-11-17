import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/domain/models/canvas/canvas_shape_type.dart';
import 'package:inklink/features/canvas/view/trays/layers_tray.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Widget _host(LayersTray tray) {
  return MaterialApp(
    theme: InkTheme.light(),
    home: Scaffold(
      body: Stack(children: [tray]),
    ),
  );
}

void main() {
  const bottom = ShapeElement(
    id: 'a',
    z: 0,
    shapeType: CanvasShapeType.square,
    center: Offset(10, 10),
    size: 40,
    color: Color(0xFF000000),
  );
  const top = TextElement(
    id: 'b',
    z: 1,
    text: 'Hello',
    center: Offset(10, 10),
    color: Color(0xFF000000),
  );

  testWidgets('lists topmost elements first and toggles visibility', (
    tester,
  ) async {
    String? toggled;
    bool? visible;
    await tester.pumpWidget(
      _host(
        LayersTray(
          isOpen: true,
          elements: const [bottom, top],
          selectedIds: const {},
          selectedShapeId: null,
          canEdit: true,
          onSelect: (_) {},
          onToggleVisibility: (id, value) {
            toggled = id;
            visible = value;
          },
          onToggleLock: (_, _) {},
          onOpacityChanged: (_, _) {},
          onReorder: (_, _) {},
          activeLayerId: null,
          onSetActiveLayer: (_) {},
          onAddLayer: (_) {},
          onRenameLayer: (_, _) {},
          onDeleteLayer: (_) {},
        ),
      ),
    );

    final textOffset = tester.getTopLeft(find.text('Hello')).dy;
    final shapeOffset = tester.getTopLeft(find.text('Square')).dy;
    expect(textOffset, lessThan(shapeOffset));

    // Hide the top row: it is currently visible, so the callback asks to hide.
    await tester.tap(find.byTooltip('Hide layer').first);
    await tester.pumpAndSettle();
    expect(toggled, 'b');
    expect(visible, isFalse);
  });

  testWidgets('lock and empty states', (tester) async {
    bool? locked;
    await tester.pumpWidget(
      _host(
        LayersTray(
          isOpen: true,
          elements: const [bottom],
          selectedIds: const {},
          selectedShapeId: null,
          canEdit: true,
          onSelect: (_) {},
          onToggleVisibility: (_, _) {},
          onToggleLock: (_, value) => locked = value,
          onOpacityChanged: (_, _) {},
          onReorder: (_, _) {},
          activeLayerId: null,
          onSetActiveLayer: (_) {},
          onAddLayer: (_) {},
          onRenameLayer: (_, _) {},
          onDeleteLayer: (_) {},
        ),
      ),
    );
    await tester.tap(find.byTooltip('Lock layer'));
    await tester.pumpAndSettle();
    expect(locked, isTrue);

    await tester.pumpWidget(_host(
      LayersTray(
        isOpen: true,
        elements: const [],
        selectedIds: const {},
        selectedShapeId: null,
        canEdit: true,
        onSelect: (_) {},
        onToggleVisibility: (_, _) {},
        onToggleLock: (_, _) {},
        onOpacityChanged: (_, _) {},
        onReorder: (_, _) {},
        activeLayerId: null,
        onSetActiveLayer: (_) {},
        onAddLayer: (_) {},
        onRenameLayer: (_, _) {},
        onDeleteLayer: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No layers yet'), findsOneWidget);
  });

  testWidgets('viewers get disabled layer controls', (tester) async {
    await tester.pumpWidget(
      _host(
        LayersTray(
          isOpen: true,
          elements: const [bottom],
          selectedIds: const {},
          selectedShapeId: null,
          canEdit: false,
          onSelect: (_) {},
          onToggleVisibility: (_, _) {},
          onToggleLock: (_, _) {},
          onOpacityChanged: (_, _) {},
          onReorder: (_, _) {},
          activeLayerId: null,
          onSetActiveLayer: (_) {},
          onAddLayer: (_) {},
          onRenameLayer: (_, _) {},
          onDeleteLayer: (_) {},
        ),
      ),
    );
    final eye = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(LucideIcons.eye),
        matching: find.byType(IconButton),
      ),
    );
    expect(eye.onPressed, isNull);
  });

  testWidgets('groups elements under named layers and picks the active one', (
    tester,
  ) async {
    String? activated;
    const layer = LayerElement(
      id: 'layer-1',
      z: 5,
      name: 'Background',
      elementIds: ['a'],
    );
    await tester.pumpWidget(
      _host(
        LayersTray(
          isOpen: true,
          elements: const [layer, bottom, top],
          selectedIds: const {},
          selectedShapeId: null,
          activeLayerId: 'layer-1',
          canEdit: true,
          onSelect: (_) {},
          onToggleVisibility: (_, _) {},
          onToggleLock: (_, _) {},
          onOpacityChanged: (_, _) {},
          onReorder: (_, _) {},
          onSetActiveLayer: (id) => activated = id,
          onAddLayer: (_) {},
          onRenameLayer: (_, _) {},
          onDeleteLayer: (_) {},
        ),
      ),
    );

    expect(find.text('Background'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Drawing into Background'), findsOneWidget);

    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();
    expect(activated, isNull);
  });

  testWidgets('offers layer creation through the name dialog', (tester) async {
    String? created;
    await tester.pumpWidget(
      _host(
        LayersTray(
          isOpen: true,
          elements: const [bottom],
          selectedIds: const {},
          selectedShapeId: null,
          activeLayerId: null,
          canEdit: true,
          onSelect: (_) {},
          onToggleVisibility: (_, _) {},
          onToggleLock: (_, _) {},
          onOpacityChanged: (_, _) {},
          onReorder: (_, _) {},
          onSetActiveLayer: (_) {},
          onAddLayer: (name) => created = name,
          onRenameLayer: (_, _) {},
          onDeleteLayer: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('New layer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ink');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(created, 'Ink');
  });

  testWidgets('long-press drag moves a row into another layer', (tester) async {
    const layer = LayerElement(
      id: 'layer-1',
      z: 0,
      name: 'Ink',
      elementIds: [],
    );
    String? movedId;
    String? movedLayer;
    var moveCalls = 0;
    await tester.pumpWidget(
      _host(
        LayersTray(
          isOpen: true,
          elements: const [layer, bottom],
          selectedIds: const {},
          selectedShapeId: null,
          activeLayerId: 'layer-1',
          canEdit: true,
          onSelect: (_) {},
          onToggleVisibility: (_, _) {},
          onToggleLock: (_, _) {},
          onOpacityChanged: (_, _) {},
          onReorder: (_, _) {},
          onMoveToLayer: (id, layerId) {
            moveCalls++;
            movedId = id;
            movedLayer = layerId;
          },
          onSetActiveLayer: (_) {},
          onAddLayer: (_) {},
          onRenameLayer: (_, _) {},
          onDeleteLayer: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('layer-a'))),
    );
    await tester.pump(const Duration(milliseconds: 320));
    await gesture.moveTo(tester.getCenter(find.text('Ink')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moveCalls, 1);
    expect(movedId, 'a');
    expect(movedLayer, 'layer-1');
  });

  testWidgets('layer menu moves a band up', (tester) async {
    const lower = LayerElement(id: 'lower', z: 0, name: 'Lower');
    const upper = LayerElement(id: 'upper', z: 1, name: 'Upper');
    String? movedLayer;
    int? movedIndex;
    await tester.pumpWidget(
      _host(
        LayersTray(
          isOpen: true,
          elements: const [lower, upper, bottom],
          selectedIds: const {},
          selectedShapeId: null,
          activeLayerId: null,
          canEdit: true,
          onSelect: (_) {},
          onToggleVisibility: (_, _) {},
          onToggleLock: (_, _) {},
          onOpacityChanged: (_, _) {},
          onReorder: (_, _) {},
          onReorderLayer: (id, index) {
            movedLayer = id;
            movedIndex = index;
          },
          onSetActiveLayer: (_) {},
          onAddLayer: (_) {},
          onRenameLayer: (_, _) {},
          onDeleteLayer: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Top-first display is Upper then Lower, so the last menu belongs to the
    // bottom band we want to raise.
    await tester.tap(find.byTooltip('Layer actions').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move up'));
    await tester.pumpAndSettle();

    expect(movedLayer, 'lower');
    expect(movedIndex, 1);
  });
}
