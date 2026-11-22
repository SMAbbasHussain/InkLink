import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/services/crashlytics_service.dart';

class _FakeCrashlyticsSink implements CrashlyticsSink {
  final List<({FlutterErrorDetails details, bool fatal})> flutterErrors = [];
  final List<({Object error, StackTrace stack, Object? reason, bool fatal})>
  errors = [];
  final Map<String, Object> customKeys = {};
  final List<String> logs = [];
  String? userId;

  @override
  Future<void> log(String message) async {
    logs.add(message);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    Object? reason,
    bool fatal = false,
  }) async {
    errors.add((error: error, stack: stack, reason: reason, fatal: fatal));
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    flutterErrors.add((details: details, fatal: fatal));
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    customKeys[key] = value;
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    userId = identifier;
  }
}

class _FailingCubit extends Cubit<int> {
  _FailingCubit() : super(0);

  void triggerError() {
    addError(StateError('cubit boom'), StackTrace.current);
  }
}

void main() {
  testWidgets(
    'Given a RenderFlex pixel overflow, Then handleFlutterError reports it as non-fatal layout_overflow',
    (tester) async {
      final sink = _FakeCrashlyticsSink();
      final service = CrashlyticsService(sink: sink);
      final previousOnError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previousOnError);
      FlutterError.onError = service.handleFlutterError;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 50,
              child: Row(
                children: [
                  SizedBox(width: 120, height: 20),
                ],
              ),
            ),
          ),
        ),
      );

      // Pump microtasks so unawaited Crashlytics calls complete.
      await tester.pump();

      expect(sink.flutterErrors, isNotEmpty);
      final reported = sink.flutterErrors.first;
      expect(reported.fatal, isFalse);
      expect(sink.customKeys['error_category'], 'layout_overflow');
      expect(
        reported.details.exceptionAsString().toLowerCase(),
        contains('overflowed'),
      );
    },
  );

  test(
    'Given a non-overflow FlutterError, Then handleFlutterError reports it as fatal',
    () async {
      final sink = _FakeCrashlyticsSink();
      final service = CrashlyticsService(sink: sink);

      service.handleFlutterError(
        FlutterErrorDetails(
          exception: StateError('widget build crash'),
          stack: StackTrace.current,
          library: 'widgets library',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(sink.flutterErrors, hasLength(1));
      expect(sink.flutterErrors.single.fatal, isTrue);
      expect(sink.customKeys['error_category'], 'widgets library');
    },
  );

  test(
    'Given an uncaught BLoC error, Then CrashlyticsBlocObserver forwards it',
    () async {
      final sink = _FakeCrashlyticsSink();
      final service = CrashlyticsService(sink: sink);
      final previousObserver = Bloc.observer;
      Bloc.observer = CrashlyticsBlocObserver(service);
      addTearDown(() => Bloc.observer = previousObserver);

      final cubit = _FailingCubit();
      addTearDown(cubit.close);
      cubit.triggerError();
      await Future<void>.delayed(Duration.zero);

      expect(sink.errors, hasLength(1));
      expect(sink.errors.single.error, isA<StateError>());
      expect(sink.errors.single.fatal, isFalse);
      expect(sink.errors.single.reason.toString(), contains('_FailingCubit'));
    },
  );

  test('setUserId updates user identifier safely', () async {
    final sink = _FakeCrashlyticsSink();
    final service = CrashlyticsService(sink: sink);

    await service.setUserId('user-123');
    expect(sink.userId, 'user-123');

    await service.setUserId(null);
    expect(sink.userId, '');
  });
}
