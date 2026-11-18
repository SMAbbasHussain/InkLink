import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web app (lib/web/) must stay compilable for the browser. It may now
/// reach the mobile canvas, but never — directly or through other app files
/// — the mobile app's Isar database (lib/core/database/), path_provider,
/// the Agora Chat SDK or the Agora voice engine.
///
/// Imports are followed the way the browser build sees them: for a
/// conditional import or export (`'a.dart' if (dart.library.js_interop)
/// 'b.dart'`) only the web file `b.dart` is followed.
void main() {
  final imports = _webImportGraph();

  bool isForbidden(String uri) =>
      uri.startsWith('package:isar') ||
      uri.contains('/core/database/') ||
      uri.startsWith('package:path_provider') ||
      uri.startsWith('package:agora_chat_sdk') ||
      uri.startsWith('package:agora_rtc_engine');

  Set<String> reachableFrom(Iterable<String> starts) {
    final seen = <String>{};
    void visit(String file) {
      if (!seen.add(file)) return;
      for (final uri in imports[file] ?? const <String>[]) {
        if (imports.containsKey(uri)) visit(uri);
      }
    }

    starts.forEach(visit);
    return seen;
  }

  test('lib/web never reaches mobile-only code', () {
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

    final webFiles = imports.keys
        .where((p) => p.startsWith('lib/web/'))
        .toList();
    expect(webFiles, isNotEmpty);
    for (final file in webFiles) {
      visit(file, const []);
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('the guard covers the canvas the web app opens', () {
    final reach = reachableFrom(['lib/web/main_web.dart']);
    expect(reach, contains('lib/features/canvas/view/canvas_screen.dart'));
    expect(reach, contains('lib/features/canvas/bloc/canvas_bloc.dart'));
    expect(
      reach,
      contains(
        'lib/domain/repositories/canvas/canvas_sync_repository_impl.dart',
      ),
    );
    // The web branches of the conditional imports are the ones followed.
    expect(
      reach,
      contains('lib/domain/models/canvas/local_crdt_update_web.dart'),
    );
    expect(
      reach,
      contains('lib/features/canvas/view/board_settings_opener_web.dart'),
    );
    expect(
      reach,
      isNot(contains('lib/features/canvas/view/board_settings_opener.dart')),
    );
  });

  test('the preview and test app does not pull in the canvas', () {
    final reach = reachableFrom(['lib/web/web_companion_app.dart']);
    expect(
      reach,
      isNot(contains('lib/features/canvas/view/canvas_screen.dart')),
    );
  });
}

/// File → the URIs it imports, exports or includes, as the web build
/// resolves them.
Map<String, List<String>> _webImportGraph() {
  final directive = RegExp(
    r"^(?:import|export|part)\s+'([^']+)'((?:\s*if\s*\([^)]*\)\s*'[^']+')*)",
    multiLine: true,
  );
  final webBranch = RegExp(
    r"if\s*\(\s*dart\.library\.(?:js_interop|html|js)\s*\)\s*'([^']+)'",
  );
  final imports = <String, List<String>>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll('\\', '/');
    final source = entity.readAsStringSync();
    final found = <String>[];
    for (final match in directive.allMatches(source)) {
      var uri = match.group(1)!;
      final web = webBranch.firstMatch(match.group(2) ?? '');
      if (web != null) uri = web.group(1)!;
      if (uri.startsWith('package:inklink/')) {
        uri = 'lib/${uri.substring('package:inklink/'.length)}';
      } else if (!uri.startsWith('package:') && !uri.startsWith('dart:')) {
        uri = Uri.parse(path).resolve(uri).path;
      }
      found.add(uri);
    }
    imports[path] = found;
  }
  return imports;
}
