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

/// Root of the web companion: theme, services and the sign-in gate.
class WebCompanionApp extends StatelessWidget {
  /// Preview mode and tests inject a sample-data repository; the real app
  /// builds the Firebase one.
  final WebCompanionRepository? repository;
  final ThemeMode themeMode;

  /// Section shown first after sign-in (Boards unless the preview asks).
  final WebSection initialSection;

  const WebCompanionApp({
    super.key,
    this.repository,
    this.themeMode = ThemeMode.system,
    this.initialSection = WebSection.boards,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<WebCompanionRepository>(
          create: (_) =>
              repository ??
              FirebaseWebCompanionRepository(
                authService: AuthServiceImpl(),
                firestoreService: FirestoreServiceImpl(),
                cloudFunctionsService: CloudFunctionsServiceImpl(),
              ),
        ),
        RepositoryProvider<WebAuthRefresh>(create: (_) => WebAuthRefresh()),
      ],
      child: MaterialApp(
        title: 'InkLink',
        debugShowCheckedModeBanner: false,
        theme: InkTheme.light(),
        darkTheme: InkTheme.dark(),
        themeMode: themeMode,
        home: _WebAuthGate(initialSection: initialSection),
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
          return WebHomeShell(key: ValueKey(user.uid), initialSection: initialSection);
        },
      ),
    );
  }
}
