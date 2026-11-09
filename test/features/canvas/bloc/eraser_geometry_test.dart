import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';

List<Offset> _denseHorizontalStroke() => <Offset>[
      for (var x = 0.0; x <= 200.0; x += 20.0) Offset(x, 0),
    ];

void main() {
  const eraserRadius = 12.0;
  const eraserX = 100.0;
  const verticalErasePath = <Offset>[Offset(eraserX, -30), Offset(eraserX, 30)];

  double distanceToEraser(Offset point) => (point.dx - eraserX).abs();

  group('splitStrokeByEraserPath', () {
    test('cuts the stroke on both sides of the eraser swath', () {
      final segments = splitStrokeByEraserPath(
        strokePoints: _denseHorizontalStroke(),
        erasePath: verticalErasePath,
        eraseRadius: eraserRadius,
      );

      expect(segments, hasLength(2));
      // No segment may span the hole, otherwise the erased ink is bridged.
      expect(segments.first.every((point) => point.dx < eraserX), isTrue);
      expect(segments.last.every((point) => point.dx > eraserX), isTrue);
      for (final segment in segments) {
        for (final point in segment) {
          expect(
            distanceToEraser(point),
            greaterThan(eraserRadius - 0.5),
            reason: 'kept points must lie outside the swept circle',
          );
        }
      }
    });

    test('cuts a stroke whose samples are spread wider than the eraser', () {
      // Regression: filtering whole points left this line untouched because the
      // eraser fell between two samples, so the stroke reappeared intact.
      final segments = splitStrokeByEraserPath(
        strokePoints: const <Offset>[Offset(0, 0), Offset(200, 0)],
        erasePath: verticalErasePath,
        eraseRadius: eraserRadius,
      );

      expect(segments, hasLength(2));
      expect(segments.first.every((point) => point.dx < eraserX), isTrue);
      expect(segments.last.every((point) => point.dx > eraserX), isTrue);
    });

    test('a single-point (tap) erase punches a hole', () {
      final segments = splitStrokeByEraserPath(
        strokePoints: _denseHorizontalStroke(),
        erasePath: const <Offset>[Offset(eraserX, 0)],
        eraseRadius: eraserRadius,
      );

      expect(segments, hasLength(2));
      expect(segments.first.last.dx, lessThan(eraserX));
      expect(segments.last.first.dx, greaterThan(eraserX));
    });

    test('returns the original points when the eraser misses', () {
      final stroke = _denseHorizontalStroke();
      final segments = splitStrokeByEraserPath(
        strokePoints: stroke,
        erasePath: const <Offset>[Offset(eraserX, 500), Offset(eraserX, 600)],
        eraseRadius: eraserRadius,
      );

      expect(segments, hasLength(1));
      expect(identical(segments.first, stroke), isTrue);
    });

    test('removes a stroke that is completely covered', () {
      final segments = splitStrokeByEraserPath(
        strokePoints: _denseHorizontalStroke(),
        erasePath: const <Offset>[Offset(-20, 0), Offset(220, 0)],
        eraseRadius: 40,
      );

      expect(segments, isEmpty);
    });
  });

  group('CanvasBloc eraser gesture', () {
    blocTest<CanvasBloc, CanvasState>(
      'erasing the middle of a stroke splits it into two unbridged fragments',
      build: CanvasBloc.new,
      act: (bloc) async {
        bloc.add(
          const CanvasBoardTitleUpdated(
            null,
            currentUserRole: Board.roleEditor,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        // Draw one stroke along y = 0.
        bloc.add(const CanvasStartStroke(Offset(0, 0)));
        bloc.add(const CanvasAppendStroke(Offset(100, 0)));
        bloc.add(const CanvasAppendStroke(Offset(200, 0)));
        bloc.add(const CanvasEndStroke());
        await Future<void>.delayed(Duration.zero);

        // Erase across its middle with a 24px eraser.
        bloc.add(const CanvasUpdateStrokeWidth(24));
        bloc.add(const CanvasUpdateBrushType('eraser'));
        bloc.add(const CanvasStartStroke(Offset(100, -40)));
        bloc.add(const CanvasAppendStroke(Offset(100, 40)));
        bloc.add(const CanvasEndStroke());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        final strokes = bloc.state.elements.whereType<StrokeElement>().toList();
        expect(strokes, hasLength(2));
        for (final stroke in strokes) {
          expect(stroke.z, 0, reason: 'fragments keep the source z order');
          for (final point in stroke.points) {
            expect(
              (point.dx - 100).abs(),
              greaterThan(eraserRadius),
              reason: 'no fragment point may sit inside the eraser swath',
            );
          }
        }
        expect(bloc.state.currentStroke, isEmpty);
      },
    );
  });
}
