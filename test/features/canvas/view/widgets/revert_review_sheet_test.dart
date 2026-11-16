import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/history/revert_plan.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/widgets/revert_review_sheet.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

Map<String, dynamic> _stroke({
  required double startX,
  required double startY,
  required double endX,
}) {
  return {
    'type': 'stroke',
    'z': 1,
    'color': 0xFF3366FF,
    'strokeWidth': 4.0,
    'opacity': 1.0,
    'brushType': 'solid',
    'points': [
      {'x': startX, 'y': startY},
      {'x': endX, 'y': startY + 20},
    ],
  };
}

void main() {
  testWidgets('shows a visual preview and swaps it with the decision', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final bloc = CanvasBloc(boardId: 'board-1', currentUserId: 'owner-1');
    addTearDown(bloc.close);

    final plan = RevertPlan(
      planId: 'plan-1',
      mode: 'user',
      baseVersion: 5,
      items: [
        RevertPlanItem(
          elementId: 'stroke-secret-id',
          kind: 'update',
          conflict: true,
          before: _stroke(startX: 10, startY: 20, endX: 90),
          after: _stroke(startX: 40, startY: 60, endX: 140),
          label: 'Blue freehand stroke',
          summary: 'Moved the stroke across the board.',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: InkTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showRevertReviewSheet(context, bloc: bloc, plan: plan),
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();

    expect(find.text('Review changes'), findsOneWidget);
    expect(find.text('Keep current'), findsOneWidget);
    expect(find.text('Restore previous'), findsOneWidget);
    expect(find.text('Current board'), findsOneWidget);
    expect(find.text('Previous version'), findsNothing);
    expect(find.textContaining('stroke-secret-id'), findsNothing);

    await tester.tap(find.text('Restore previous'));
    await tester.pumpAndSettle();

    expect(find.text('Previous version'), findsOneWidget);
    expect(find.text('Current board'), findsNothing);
    expect(find.textContaining('stroke-secret-id'), findsNothing);
  });
}
