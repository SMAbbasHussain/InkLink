import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/board_template.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';

void main() {
  group('BoardTemplate catalog', () {
    test('Given every built-in template, Then elements parse and ids are '
        'unique', () {
      for (final template in canvasTemplates) {
        final ids = <String>{};
        for (final element in template.elements) {
          final id = element['id'] as String;
          expect(ids.add(id), isTrue, reason: '${template.id}: duplicate $id');
          final payload = Map<String, dynamic>.from(element)..remove('id');
          expect(
            () => CanvasElement.fromMap(id, payload),
            returnsNormally,
            reason: '${template.id}: $id',
          );
        }
      }
    });

    test('Given connector templates, Then endpoints resolve to template ids',
        () {
      for (final template in canvasTemplates) {
        final ids = template.elements
            .map((element) => element['id'])
            .whereType<String>()
            .toSet();
        for (final element in template.elements) {
          if (element['type'] != 'connector') continue;
          expect(ids, contains(element['startElementId']));
          expect(ids, contains(element['endElementId']));
        }
      }
    });

    test('Given an empty board template, Then it imports nothing', () {
      final blank = canvasTemplates.firstWhere(
        (template) => template.id == 'blank',
      );
      expect(blank.isEmpty, isTrue);
      expect(blank.center, Offset.zero);
    });

    test('Given a template, Then center averages element centers', () {
      final template = BoardTemplate(
        id: 't',
        name: 'T',
        description: '',
        elements: [
          {'id': 'a', 'type': 'sticky_note', 'cx': 0, 'cy': 0},
          {'id': 'b', 'type': 'sticky_note', 'cx': 100, 'cy': 200},
        ],
      );
      expect(template.center, const Offset(50, 100));
    });
  });

  group('BoardTemplate.fromJson', () {
    test('Given a valid file, Then metadata and elements are kept', () {
      final template = BoardTemplate.fromJson(const {
        'id': 'custom',
        'name': 'Custom',
        'description': 'Test',
        'category': 'Test',
        'elements': [
          {'id': 'a', 'type': 'sticky_note', 'cx': 0, 'cy': 0},
        ],
      });
      expect(template.id, 'custom');
      expect(template.category, 'Test');
      expect(template.elements.single['id'], 'a');
    });

    test('Given an unknown element type, Then it throws', () {
      expect(
        () => BoardTemplate.fromJson(const {
          'elements': [
            {'id': 'a', 'type': 'not-real', 'cx': 0, 'cy': 0},
          ],
        }),
        throwsArgumentError,
      );
    });

    test('Given duplicate placeholders, Then it throws', () {
      expect(
        () => BoardTemplate.fromJson(const {
          'elements': [
            {'id': 'a', 'type': 'sticky_note', 'cx': 0, 'cy': 0},
            {'id': 'a', 'type': 'sticky_note', 'cx': 10, 'cy': 10},
          ],
        }),
        throwsArgumentError,
      );
    });

    test('Given a non-list elements field, Then it throws', () {
      expect(
        () => BoardTemplate.fromJson(const {'elements': 'nope'}),
        throwsArgumentError,
      );
    });
  });
}
