import 'dart:io';

/// `flutter test` sets `FLUTTER_TEST` in the process environment.
bool get isFlutterTestEnvironment =>
    Platform.environment.containsKey('FLUTTER_TEST');
