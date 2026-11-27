/// Whether the app is running under `flutter test`.
///
/// The phone/desktop build reads `Platform.environment`, which does not exist
/// in a browser. The web build gets a stub instead, so no `dart:io` code can
/// run on the web (see `test_environment_io.dart` / `test_environment_web.dart`).
library;

export 'test_environment_io.dart'
    if (dart.library.js_interop) 'test_environment_web.dart'
    show isFlutterTestEnvironment;
