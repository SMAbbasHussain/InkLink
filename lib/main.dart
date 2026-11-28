import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/app/app.dart';
import 'package:inklink/app/bootstrap/firebase_bootstrap.dart';
import 'package:inklink/app/composition/mobile_dependencies.dart';
import 'package:inklink/core/services/crashlytics_service.dart';

export 'package:inklink/app/app.dart'
    show InitializationErrorApp, MyApp, appNavigatorKey;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadAppEnvironment(ignoreErrors: true);

  // Any startup failure (Firebase init, SharedPreferences, theme load, or
  // local database init) would otherwise escape main() as an unhandled
  // exception — blank/crashed app. Fall back to InitializationErrorApp.
  try {
    final dependencies = await MobileDependencies.bootstrap(
      navigatorKey: appNavigatorKey,
    );
    runApp(
      MultiRepositoryProvider(
        providers: dependencies.buildRepositoryProviders(),
        child: MultiBlocProvider(
          providers: dependencies.buildBlocProviders(),
          child: const MyApp(),
        ),
      ),
    );
  } catch (e, st) {
    debugPrint('Startup failed: $e\n$st');
    unawaited(
      CrashlyticsService.instance.recordError(
        e,
        st,
        reason: 'App startup failed',
        fatal: true,
      ),
    );
    runApp(InitializationErrorApp(error: e.toString()));
  }
}
