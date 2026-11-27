import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/services/auth_service.dart';
import '../core/services/cloud_functions_service.dart';
import '../core/services/firestore_service.dart';
import '../ui/theme/ink_theme.dart';
import 'data/firebase_web_companion_repository.dart';
import 'data/web_account.dart';
import 'data/web_companion_repository.dart';
import 'screens/home_shell.dart';
import 'screens/sign_in_screen.dart';
import 'screens/web_shell_nav.dart';
import 'widgets/web_widgets.dart';
import 'web_theme.dart';

/// Root of the web companion: theme, services and the sign-in gate. Uses the
/// mobile app's Ink theme (light and dark) so both look the same.
class WebCompanionApp extends StatefulWidget {
  /// Preview mode and tests inject a sample-data repository; the real app
  /// builds the Firebase one.
  final WebCompanionRepository? repository;
  final ThemeMode themeMode;

  /// Section shown first after sign-in (Boards unless the preview asks).
  final WebSection initialSection;

  /// What a board card does. The web app (main_web.dart) opens the canvas;
  /// without one, cards show the "open in the app" details.
  final WebBoardOpener? boardOpener;

  const WebCompanionApp({
    super.key,
    this.repository,
    this.themeMode = ThemeMode.system,
    this.initialSection = WebSection.boards,
    this.boardOpener,
  });

  @override
  State<WebCompanionApp> createState() => _WebCompanionAppState();
}

class _WebCompanionAppState extends State<WebCompanionApp> {
  // A fixed mode (preview URLs, tests) is not overridden by a saved choice.
  late final WebThemeController _theme = WebThemeController(
    widget.themeMode,
    persist: widget.themeMode == ThemeMode.system,
  );

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<WebCompanionRepository>(
          create: (_) =>
              widget.repository ??
              FirebaseWebCompanionRepository(
                authService: AuthServiceImpl(),
                firestoreService: FirestoreServiceImpl(),
                cloudFunctionsService: CloudFunctionsServiceImpl(),
              ),
        ),
        RepositoryProvider<WebAuthRefresh>(create: (_) => WebAuthRefresh()),
        RepositoryProvider<WebBoardOpener>.value(
          value: widget.boardOpener ?? WebBoardOpener.appLinks,
        ),
        RepositoryProvider<WebThemeController>.value(value: _theme),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _theme.mode,
        builder: (context, mode, _) => MaterialApp(
          title: 'InkLink',
          debugShowCheckedModeBanner: false,
          theme: InkTheme.light(),
          darkTheme: InkTheme.dark(),
          themeMode: mode,
          home: _WebAuthGate(initialSection: widget.initialSection),
        ),
      ),
    );
  }
}

/// Signed out → sign-in; unverified email → verify; otherwise the app.
class _WebAuthGate extends StatelessWidget {
  final WebSection initialSection;
  const _WebAuthGate({required this.initialSection});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<WebCompanionRepository>();
    return ListenableBuilder(
      listenable: context.read<WebAuthRefresh>().listenable,
      builder: (context, _) => StreamBuilder<WebAccount?>(
        stream: repo.authChanges,
        initialData: repo.currentUser,
        builder: (context, snapshot) {
          final user = repo.currentUser ?? snapshot.data;
          if (user == null) return const WebSignInScreen();
          if (user.usesPassword && !user.emailVerified) {
            return WebVerifyEmailScreen(email: user.email ?? 'your email');
          }
          return WebHomeShell(
            key: ValueKey(user.uid),
            initialSection: initialSection,
          );
        },
      ),
    );
  }
}
