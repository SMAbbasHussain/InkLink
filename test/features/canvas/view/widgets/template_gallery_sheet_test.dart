import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/board_template.dart';
import 'package:inklink/features/canvas/view/widgets/template_gallery_sheet.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

void main() {
  testWidgets('Given templates, Then tapping one selects it', (tester) async {
    BoardTemplate? selected;
    const templates = [
      BoardTemplate(
        id: 'a',
        name: 'Alpha',
        description: 'First layout',
      ),
      BoardTemplate(
        id: 'b',
        name: 'Beta',
        description: 'Second layout',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: InkTheme.light(),
        home: Scaffold(
          body: TemplateGallerySheet(
            templates: templates,
            onSelected: (template) => selected = template,
          ),
        ),
      ),
    );

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.text('Beta'));
    await tester.pump();

    expect(selected?.id, 'b');
  });
}
