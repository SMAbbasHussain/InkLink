import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inklink/app_view.dart';
import 'package:inklink/core/theme/app_theme.dart';
import 'package:inklink/core/services/firestore_service.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/core/services/cloud_functions_service.dart';
import 'package:inklink/domain/repositories/auth/auth_repository.dart';
import 'package:inklink/domain/repositories/auth/auth_repository_impl.dart';
import 'package:inklink/domain/repositories/board/board_repository.dart';
import 'package:inklink/domain/repositories/board/board_repository_impl.dart';
import 'package:inklink/domain/repositories/canvas/canvas_sync_repository.dart';
import 'package:inklink/domain/repositories/canvas/canvas_sync_repository_impl.dart';
import 'package:inklink/core/database/database_service.dart';
import 'package:inklink/domain/repositories/profile/profile_repository_impl.dart';
import 'package:inklink/domain/repositories/social/social_repository.dart';
import 'package:inklink/domain/repositories/profile/profile_repository.dart';
import 'package:inklink/domain/repositories/social/social_repository_impl.dart';
import 'package:inklink/domain/repositories/settings/settings_repository.dart';
import 'package:inklink/domain/repositories/settings/settings_repository_impl.dart';
import 'package:inklink/domain/repositories/theme/theme_repository_impl.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_event.dart';
import 'package:inklink/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:inklink/features/friends/bloc/friends_bloc.dart';
import 'package:inklink/features/navigation/bloc/nav_bloc.dart';
import 'package:inklink/features/theme/bloc/theme_bloc.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final themeRepository = ThemeRepositoryImpl();
  final initialThemeMode = await themeRepository.getThemeMode();

  final databaseService = DatabaseService();
  // Ensure DB drops tables or is initialized
  await databaseService.database;

  runApp(
    // 0. Firebase Services (provide first, before repositories)
    MultiRepositoryProvider(
      providers: [
        // Firebase service abstractions
        RepositoryProvider<FirestoreService>(
          create: (context) => FirestoreServiceImpl(),
        ),
        RepositoryProvider<AuthService>(create: (context) => AuthServiceImpl()),
        RepositoryProvider<CloudFunctionsService>(
          create: (context) => CloudFunctionsServiceImpl(),
        ),
        // Other services
        RepositoryProvider<DatabaseService>.value(value: databaseService),
        // 1. Repositories (depend on Firebase services)
        RepositoryProvider<AuthRepository>(
          create: (context) => FirebaseAuthRepository(
            authService: context.read<AuthService>(),
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
        RepositoryProvider<SocialRepository>(
          create: (context) => SocialRepositoryImpl(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
            functionsService: context.read<CloudFunctionsService>(),
          ),
        ),
        RepositoryProvider<ProfileRepository>(
          create: (context) => ProfileRepositoryImpl(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
          ),
        ),
        RepositoryProvider<BoardRepository>(
          create: (context) => FirestoreBoardRepository(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
            dbService: context.read<DatabaseService>(),
          ),
        ),
        RepositoryProvider<CanvasSyncRepository>(
          create: (context) => FirestoreCanvasSyncRepository(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
            dbService: context.read<DatabaseService>(),
          ),
        ),
        RepositoryProvider<SettingsRepository>(
          create: (context) =>
              SettingsRepositoryImpl(databaseService: databaseService),
        ),
      ],
      // 2. BLoCs (depend on repositories)
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                ThemeBloc(
                  themeRepository: themeRepository,
                  initialMode: initialThemeMode,
                )..add(
                  LoadTheme(),
                ), // FIX: Trigger LoadTheme to sync theme state properly
          ),
          BlocProvider(create: (context) => NavBloc()),
          BlocProvider(
            create: (context) =>
                DashboardBloc(boardRepo: context.read<BoardRepository>()),
          ),
          BlocProvider(
            create: (context) =>
                AuthBloc(authRepository: context.read<AuthRepository>())..add(
                  AuthCheckRequested(),
                ), // <--- Add this line to trigger check on start
          ),
          BlocProvider(
            create: (context) => FriendsBloc(
              socialRepo: context
                  .read<SocialRepository>(), // Reads from RepoProvider
            ),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp(
          title: 'InkLink',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          // This allows the app to respect System, Light, or Dark mode
          themeMode: themeMode,
          home: const AppView(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class InitializationErrorApp extends StatelessWidget {
  final String error;
  const InitializationErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                const Text(
                  "Failed to initialize app",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
