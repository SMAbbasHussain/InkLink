import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inklink/app_view.dart';
import 'package:inklink/core/theme/app_theme.dart';
import 'package:inklink/domain/repositories/auth_repository.dart';
import 'package:inklink/domain/repositories/auth_repository_impl.dart';
import 'package:inklink/domain/repositories/board_repository.dart';
import 'package:inklink/domain/repositories/social_repository.dart';
import 'package:inklink/domain/repositories/social_repository_impl.dart';
import 'package:inklink/domain/repositories/profile_repository.dart';
import 'package:inklink/domain/repositories/profile_repository_impl.dart';
import 'package:inklink/domain/repositories/theme_repository.dart'; // Add this
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_event.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/friends/bloc/friends_bloc.dart';
import 'package:inklink/features/navigation/bloc/nav_bloc.dart';
import 'package:inklink/features/theme/bloc/theme_bloc.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final themeRepository = ThemeRepository();
  final initialThemeMode = await themeRepository.getThemeMode();

  runApp(
    // 1. Repositories first
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (context) => FirebaseAuthRepository(),
        ),
        RepositoryProvider<SocialRepository>(
          create: (context) => SocialRepositoryImpl(),
        ),
        RepositoryProvider<ProfileRepository>(
          create: (context) => ProfileRepositoryImpl(),
        ),
        RepositoryProvider<BoardRepository>(
          create: (context) => BoardRepository(),
        ),
      ],
      // 2. Blocs second
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
          BlocProvider(
            create: (context) =>
                CanvasBloc(boardRepo: context.read<BoardRepository>()),
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
