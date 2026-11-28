import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/services/auth_service.dart';
import '../core/services/cloud_functions_service.dart';
import '../core/services/firestore_service.dart';
import '../domain/services/board/board_service.dart';
import '../ui/theme/ink_theme.dart';
import 'canvas/web_board_repository.dart';
import 'canvas/web_canvas_support.dart';
import 'data/firebase_web_companion_repository.dart';
import 'data/web_account.dart';
import 'data/web_companion_repository.dart';
import 'domain/web_companion_service.dart';
import 'screens/home_shell.dart';
import 'screens/sign_in_screen.dart';
import 'screens/web_shell_nav.dart';
import 'web_theme.dart';
import 'widgets/web_widgets.dart';

/// Root of the web companion: theme, services and the sign-in gate. Uses the
/// mobile app's Ink theme (light and dark) so both look the same.
class WebCompanionApp extends StatefulWidget {
  /// Production web passes a pre-wired [WebCompanionService] from
  /// `WebDependencies.bootstrap()`.
  final WebCompanionService? service;

  /// Preview mode and widget tests may inject a sample-data
  /// [WebCompanionRepository], which is automatically wrapped in
  /// [WebCompanionServiceImpl.fromRepository].
  final WebCompanionRepository? repository;
  final ThemeMode themeMode;

  /// Section shown first after sign-in (Boards unless the preview asks).
  final WebSection initialSection;

  /// Board from a `/board/<id>` deep link, opened after the first frame.
  final String? initialBoardId;

  /// What a board card does. The web app (`main_web.dart`) opens the canvas;
  /// without one, cards show the "open in the app" details.
  final WebBoardOpener? boardOpener;

  const WebCompanionApp({
    super.key,
    this.service,
    this.repository,
    this.themeMode = ThemeMode.system,
    this.initialSection = WebSection.boards,
    this.initialBoardId,
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

  WebCompanionService _resolveService() {
    if (widget.service != null) return widget.service!;
    if (widget.repository != null) {
      return WebCompanionServiceImpl.fromRepository(widget.repository!);
    }
    final auth = AuthServiceImpl();
    final firestore = FirestoreServiceImpl();
    final functions = CloudFunctionsServiceImpl();
    final boardRepo = WebBoardRepository(
      authService: auth,
      firestoreService: firestore,
    );
    final notificationRepo = WebNotificationRepository(
      authService: auth,
      firestoreService: firestore,
    );
    return WebCompanionServiceImpl(
      data: FirebaseWebCompanionRepository(
        authService: auth,
        firestoreService: firestore,
        boardRepository: boardRepo,
        notificationRepository: notificationRepo,
      ),
      boardService: BoardServiceImpl(
        boardRepository: boardRepo,
        cloudFunctionsService: functions,
      ),
      cloudFunctionsService: functions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<WebCompanionService>(
          create: (_) => _resolveService(),
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
          home: _WebAuthGate(
            initialSection: widget.initialSection,
            initialBoardId: widget.initialBoardId,
          ),
        ),
      ),
    );
  }
}

/// Signed out → sign-in; unverified email → verify; otherwise the app.
class _WebAuthGate extends StatelessWidget {
  final WebSection initialSection;
  final String? initialBoardId;

  const _WebAuthGate({required this.initialSection, this.initialBoardId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<WebCompanionService>();
    return ListenableBuilder(
      listenable: context.read<WebAuthRefresh>().listenable,
      builder: (context, _) => StreamBuilder<WebAccount?>(
        stream: service.authChanges,
        initialData: service.currentUser,
        builder: (context, snapshot) {
          final user = service.currentUser ?? snapshot.data;
          if (user == null) {
            return WebSignInScreen(targetBoardId: initialBoardId);
          }
          if (user.usesPassword && !user.emailVerified) {
            return WebVerifyEmailScreen(email: user.email ?? 'your email');
          }
          return WebHomeShell(
            key: ValueKey(user.uid),
            initialSection: initialSection,
            initialBoardId: initialBoardId,
          );
        },
      ),
    );
  }
}
