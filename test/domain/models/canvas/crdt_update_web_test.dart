import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web stand-in for `LocalCrdtUpdate` must have exactly the fields of
/// the Isar collection (same names and types), or the shared canvas code
/// would behave differently on the web.
void main() {
  Map<String, String> fieldsOf(String path) {
    final source = File(path).readAsStringSync();
    final body = source.substring(source.indexOf('class LocalCrdtUpdate'));
    final fields = <String, String>{};
    final pattern = RegExp(
      r'^\s+(?:late\s+)?([A-Za-z<>?]+)\s+([a-zA-Z][a-zA-Z0-9]*)\s*(?:=[^;]*)?;',
      multiLine: true,
    );
    for (final m in pattern.allMatches(body)) {
      final type = m.group(1)! == 'Id' ? 'int' : m.group(1)!;
      fields[m.group(2)!] = type;
    }
    return fields;
  }

  test('web LocalCrdtUpdate has the same fields as the Isar collection', () {
    final isar = fieldsOf(
      'lib/core/database/collections/local_crdt_update.dart',
    );
    final web = fieldsOf('lib/domain/models/canvas/local_crdt_update_web.dart');
    expect(
      isar.keys,
      containsAll(<String>[
        'id',
        'updateId',
        'boardId',
        'elementId',
        'action',
        'affectedElementIds',
        'payloadBase64',
        'sourceClientId',
        'appliedAt',
        'version',
        'isSynced',
        'isDeleted',
      ]),
    );
    expect(web, isar);
  });

  test('the shared code imports the record through the conditional export', () {
    const files = [
      'lib/features/canvas/bloc/canvas_bloc.dart',
      'lib/domain/services/canvas/canvas_service.dart',
      'lib/domain/repositories/canvas/canvas_sync_repository.dart',
      'lib/domain/repositories/canvas/canvas_sync_repository_impl.dart',
      'lib/domain/repositories/canvas/crdt_local_store.dart',
      'lib/domain/repositories/canvas/memory_crdt_local_store.dart',
    ];
    for (final f in files) {
      final source = File(f).readAsStringSync();
      expect(source, contains('models/canvas/crdt_update.dart'), reason: f);
      expect(source, isNot(contains('core/database/')), reason: f);
      expect(source, isNot(contains('package:isar')), reason: f);
    }
  });
}
