import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web companion (lib/web/) must stay compilable for the browser, which
/// means it may never import — directly or through other app files — the
/// mobile app's Isar database, path_provider or the Agora Chat SDK.
void main() {
  test('lib/web never reaches mobile-only code', () {
    final imports = <String, List<String>>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final source = entity.readAsStringSync();
      final found = <String>[];
      for (final match in RegExp(r"^(?:import|export|part)\s+'([^']+)'", multiLine: true)
          .allMatches(source)) {
        var uri = match.group(1)!;
        if (uri.startsWith('package:inklink/')) {
          uri = 'lib/${uri.substring('package:inklink/'.length)}';
        } else if (!uri.startsWith('package:') && !uri.startsWith('dart:')) {
          uri = Uri.parse(path).resolve(uri).path;
        }
        found.add(uri);
      }
      imports[path] = found;
    }

    bool isForbidden(String uri) =>
        uri.startsWith('package:isar') ||
        uri.contains('/core/database/') ||
        uri.startsWith('package:path_provider') ||
        uri.startsWith('package:agora_chat_sdk');

    final violations = <String>[];
    final visited = <String>{};
    void visit(String file, List<String> chain) {
      if (!visited.add(file)) return;
      for (final uri in imports[file] ?? const <String>[]) {
        if (isForbidden(uri)) {
          violations.add([...chain, file, uri].join(' -> '));
        } else if (imports.containsKey(uri)) {
          visit(uri, [...chain, file]);
        }
      }
    }

    final webFiles = imports.keys.where((p) => p.startsWith('lib/web/')).toList();
    expect(webFiles, isNotEmpty);
    for (final file in webFiles) {
      visit(file, const []);
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
