import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/view/widgets/sticky_note_editor_dialog.dart';
import 'package:inklink/features/canvas/view/widgets/color_picker_sheet.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    ValueChanged<StickyNoteElement?> result, {
    Size size = const Size(800, 900),
    String? author,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: InkTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open'),
              onPressed: () async {
                result(
                  await showStickyNoteEditor(
                    context,
                    note: StickyNoteElement(
                      id: 'note',
                      z: 2,
                      center: const Offset(100, 100),
                      text: 'Before',
                      autoSize: true,
                      authorUid: author,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Given editor, When text and style change, Then save returns one complete note',
    (tester) async {
      StickyNoteElement? result;
      await open(tester, (n) => result = n);
      await tester.enterText(
        find.byKey(const Key('sticky-editor-text')),
        List.filled(30, 'ideas').join(' '),
      );
      await tester.ensureVisible(find.byKey(const Key('sticky-bold')));
      await tester.tap(find.byKey(const Key('sticky-bold')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sticky-align-center')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sticky-editor-save')));
      await tester.pumpAndSettle();
      expect(result!.fontWeight, 700);
      expect(result!.textAlign, 'center');
      expect(result!.height, greaterThan(160));
      expect(result!.autoSize, isTrue);
      expect(result!.id, 'note');
      expect(result!.center, const Offset(100, 100));
    },
  );

  testWidgets(
    'Given small viewport, Then color picker opens and cancel discards draft without overflow',
    (tester) async {
      StickyNoteElement? result;
      await open(tester, (n) => result = n, size: const Size(390, 500));
      expect(find.textContaining('Author:'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('sticky-paper-color')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sticky-paper-color')));
      await tester.pumpAndSettle();
      expect(find.byType(ColorPickerSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(ColorPickerSheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sticky-editor-cancel')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Given author and auto-height, When disabled, Then manual frame and author are retained',
    (tester) async {
      StickyNoteElement? result;
      await open(tester, (n) => result = n, author: 'author-1');
      expect(find.text('Author: author-1'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('sticky-auto-height')));
      await tester.tap(find.byKey(const Key('sticky-auto-height')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sticky-editor-save')));
      await tester.pumpAndSettle();
      expect(result!.autoSize, isFalse);
      expect(result!.height, 160);
      expect(result!.authorUid, 'author-1');
    },
  );
}
