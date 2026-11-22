import 'dart:async';
import 'dart:isolate';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Abstraction over [FirebaseCrashlytics] so error-routing logic can be
/// unit-tested without an active Firebase app.
abstract class CrashlyticsSink {
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  });

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    Object? reason,
    bool fatal = false,
  });

  Future<void> setCustomKey(String key, Object value);
  Future<void> setUserIdentifier(String identifier);
  Future<void> log(String message);
}

class _FirebaseCrashlyticsSink implements CrashlyticsSink {
  FirebaseCrashlytics? get _instance =>
      Firebase.apps.isNotEmpty ? FirebaseCrashlytics.instance : null;

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    final crashlytics = _instance;
    if (crashlytics == null) return;
    if (fatal) {
      await crashlytics.recordFlutterFatalError(details);
    } else {
      await crashlytics.recordFlutterError(details, fatal: false);
    }
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    Object? reason,
    bool fatal = false,
  }) async {
    final crashlytics = _instance;
    if (crashlytics == null) return;
    await crashlytics.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    final crashlytics = _instance;
    if (crashlytics == null) return;
    await crashlytics.setCustomKey(key, value);
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    final crashlytics = _instance;
    if (crashlytics == null) return;
    await crashlytics.setUserIdentifier(identifier);
  }

  @override
  Future<void> log(String message) async {
    final crashlytics = _instance;
    if (crashlytics == null) return;
    await crashlytics.log(message);
  }
}

/// Centralized Crashlytics wiring for Flutter framework errors (including
/// pixel overflows), uncaught async/zone errors, isolate errors, and BLoC
/// errors.
class CrashlyticsService {
  CrashlyticsService({CrashlyticsSink? sink})
    : _sink = sink ?? _FirebaseCrashlyticsSink();

  static final CrashlyticsService instance = CrashlyticsService();

  final CrashlyticsSink _sink;
  RawReceivePort? _isolateErrorPort;
  bool _initialized = false;

  /// Returns whether [details] represents a RenderFlex / layout pixel overflow.
  static bool isLayoutOverflow(FlutterErrorDetails details) {
    final text = details.exceptionAsString().toLowerCase();
    return text.contains('overflowed') ||
        text.contains('renderflex overflow');
  }

  /// Registers global Flutter, PlatformDispatcher, Isolate, and BLoC error
  /// handlers to forward crashes and non-fatal layout overflows to Crashlytics.
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    FlutterError.onError = handleFlutterError;

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(recordError(error, stack, fatal: true));
      return true;
    };

    Bloc.observer = CrashlyticsBlocObserver(this);

    if (!kIsWeb) {
      _isolateErrorPort ??= RawReceivePort((dynamic pair) {
        if (pair is List && pair.length >= 2) {
          final error = pair[0] ?? 'Unknown isolate error';
          final rawStack = pair[1]?.toString() ?? '';
          final stack = rawStack.isNotEmpty
              ? StackTrace.fromString(rawStack)
              : StackTrace.current;
          unawaited(
            recordError(
              error,
              stack,
              reason: 'Uncaught isolate error',
              fatal: true,
            ),
          );
        }
      });
      Isolate.current.addErrorListener(_isolateErrorPort!.sendPort);
    }
  }

  /// Handles a [FlutterErrorDetails] reported by the Flutter framework.
  ///
  /// Layout pixel overflows are recorded as non-fatal issues tagged with
  /// `error_category = layout_overflow`; all other framework errors are
  /// recorded as fatal crashes.
  void handleFlutterError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
    final overflow = isLayoutOverflow(details);
    if (overflow) {
      unawaited(_safeSetKey('error_category', 'layout_overflow'));
      unawaited(_safeSetKey('error_library', details.library ?? 'rendering'));
    } else {
      unawaited(
        _safeSetKey('error_category', details.library ?? 'flutter_framework'),
      );
    }
    unawaited(
      _safeRecordFlutterError(
        details,
        fatal: !overflow,
      ),
    );
  }

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      await _sink.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (_) {
      // Never let telemetry reporting crash the app.
    }
  }

  Future<void> log(String message) async {
    try {
      await _sink.log(message);
    } catch (_) {}
  }

  Future<void> setUserId(String? userId) async {
    try {
      await _sink.setUserIdentifier(userId ?? '');
    } catch (_) {}
  }

  Future<void> _safeRecordFlutterError(
    FlutterErrorDetails details, {
    required bool fatal,
  }) async {
    try {
      await _sink.recordFlutterError(details, fatal: fatal);
    } catch (_) {}
  }

  Future<void> _safeSetKey(String key, Object value) async {
    try {
      await _sink.setCustomKey(key, value);
    } catch (_) {}
  }
}

/// Forwards uncaught BLoC/Cubit errors (which `flutter_bloc` catches before
/// reaching `PlatformDispatcher.onError`) to [CrashlyticsService].
class CrashlyticsBlocObserver extends BlocObserver {
  CrashlyticsBlocObserver(this._crashlytics);

  final CrashlyticsService _crashlytics;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    unawaited(
      _crashlytics.recordError(
        error,
        stackTrace,
        reason: 'Uncaught error in ${bloc.runtimeType}',
        fatal: false,
      ),
    );
  }
}
