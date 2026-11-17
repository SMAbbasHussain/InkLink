import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/services/auth_service.dart';
import '../core/services/cloud_functions_service.dart';
import '../core/services/firestore_service.dart';
import '../ui/theme/ink_theme.dart';
import 'data/web_companion_repository.dart';
import 'screens/home_shell.dart';
import 'screens/sign_in_screen.dart';

/// Root of the web companion: theme, services and the sign-in gate.
class WebCompanionApp extends StatelessWidget {
  /// Tests can inject a repository; the real app builds one from Firebase.
  final WebCompanionRepository? repository;

  const WebCompanionApp({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<WebCompanionRepository>(
          create: (_) =>
              repository ??
              WebCompanionRepository(
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
        themeMode: ThemeMode.system,
        home: const _WebAuthGate(),
      ),
    );
  }
}

/// Signed out → sign-in; unverified email → verify; otherwise the app.
class _WebAuthGate extends StatelessWidget {
  const _WebAuthGate();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<WebCompanionRepository>();
    return ListenableBuilder(
      listenable: context.read<WebAuthRefresh>(),
      builder: (context, _) => StreamBuilder<User?>(
        stream: repo.authChanges,
        initialData: repo.currentUser,
        builder: (context, snapshot) {
          final user = repo.currentUser ?? snapshot.data;
          if (user == null) return const WebSignInScreen();
          final usesPassword =
              user.providerData.any((p) => p.providerId == 'password');
          if (usesPassword && !user.emailVerified) {
            return WebVerifyEmailScreen(email: user.email ?? 'your email');
          }
          return WebHomeShell(key: ValueKey(user.uid));
        },
      ),
    );
  }
}
