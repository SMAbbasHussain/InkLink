import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web build must never run native platform code by accident. These are
/// the platform checks that used to sit behind `!kIsWeb` guards in shared
/// files; they now live in conditional imports, and this test keeps them
/// there.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('the snackbar does not import dart:io or read Platform', () {
    final source = read('lib/core/utils/app_snackbar.dart');
    expect(source, contains("import 'test_environment.dart';"));
    expect(source.contains("import 'dart:io'"), isFalse);
    expect(source.contains('Platform.'), isFalse);
    expect(source.contains('kIsWeb'), isFalse);
  });

  test('the test-environment check has a web branch without dart:io', () {
    final library = read('lib/core/utils/test_environment.dart');
    expect(library, contains('if (dart.library.js_interop)'));
    expect(
      read('lib/core/utils/test_environment_io.dart'),
      contains("Platform.environment.containsKey('FLUTTER_TEST')"),
    );
    final web = read('lib/core/utils/test_environment_web.dart');
    expect(web.contains('dart:io'), isFalse);
    expect(web, contains('isFlutterTestEnvironment'));
  });

  test('export folders are resolved behind a conditional import', () {
    final service = read(
      'lib/domain/services/canvas/board_export_service.dart',
    );
    expect(service, contains("import 'export_storage.dart';"));
    expect(service.contains('Platform.'), isFalse);
    expect(service.contains('_resolveExportDirectory'), isFalse);
    expect(service.contains('getApplicationDocumentsDirectory'), isFalse);

    final library = read('lib/domain/services/canvas/export_storage.dart');
    expect(library, contains('if (dart.library.js_interop)'));
    expect(
      read('lib/domain/services/canvas/export_storage_io.dart'),
      contains('Platform.isAndroid'),
    );

    final web = read('lib/domain/services/canvas/export_storage_web.dart');
    expect(web.contains('dart:io'), isFalse);
    expect(web, contains('UnsupportedError'));
  });

  test('WebBoardRepository implements every member', () {
    final source = read(
      'lib/web/domain/repositories/web_board_repository.dart',
    );
    expect(source, contains('implements BoardRepository'));
    expect(RegExp(r'noSuchMethod\s*\(').hasMatch(source), isFalse);
    // The web now implements the whole interface, so nothing may fall back to
    // a runtime "not available on the web" error.
    expect(source.contains('UnsupportedError'), isFalse);
  });

  test('the canvas hides mobile-only UI in the browser', () {
    final source = read('lib/features/canvas/view/canvas_screen.dart');
    // Voice calls are mobile-only: the HUD must not mount on the web.
    expect(source, contains('if (!kIsWeb) const VoiceCallHud()'));
    // Browsers turn `camera` into a file chooser, so it is hidden on the web.
    expect(source, contains('if (!kIsWeb) ...['));
  });
}
