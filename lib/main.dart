import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:inklink/app_view.dart';
import 'package:inklink/core/theme/app_theme.dart';
import 'package:inklink/core/services/firestore_service.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/core/services/cloud_functions_service.dart';
import 'package:inklink/core/services/local_notification_service.dart';
import 'package:inklink/core/services/messaging_service.dart';
import 'package:inklink/domain/repositories/auth/auth_repository.dart';
import 'package:inklink/domain/repositories/auth/auth_repository_impl.dart';
import 'package:inklink/domain/repositories/board/board_repository.dart';
import 'package:inklink/domain/repositories/board/board_repository_impl.dart';
import 'package:inklink/domain/repositories/canvas/canvas_sync_repository.dart';
import 'package:inklink/domain/repositories/canvas/canvas_sync_repository_impl.dart';
import 'package:inklink/domain/repositories/invitation/invitation_repository.dart';
import 'package:inklink/domain/repositories/invitation/invitation_repository_impl.dart';
import 'package:inklink/domain/repositories/notification/notification_repository.dart';
import 'package:inklink/domain/repositories/notification/notification_repository_impl.dart';
import 'package:inklink/core/database/local_database_service.dart';
import 'package:inklink/domain/repositories/profile/profile_repository_impl.dart';
import 'package:inklink/domain/repositories/friends/friends_repository.dart';
import 'package:inklink/domain/repositories/profile/profile_repository.dart';
import 'package:inklink/domain/repositories/friends/friends_repository_impl.dart';
import 'package:inklink/domain/repositories/settings/settings_repository.dart';
import 'package:inklink/domain/repositories/settings/settings_repository_impl.dart';
import 'package:inklink/domain/repositories/theme/theme_repository_impl.dart';
import 'package:inklink/domain/services/auth/auth_session_service.dart';
import 'package:inklink/domain/services/board/board_service.dart';
import 'package:inklink/domain/services/friends/friends_service.dart';
import 'package:inklink/domain/services/invitation/invitation_service.dart';
import 'package:inklink/domain/services/presence/presence_service.dart';
import 'package:inklink/domain/services/profile/profile_service.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_event.dart';
import 'package:inklink/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:inklink/features/friends/bloc/friends_bloc.dart';
import 'package:inklink/features/navigation/bloc/nav_bloc.dart';
import 'package:inklink/features/theme/bloc/theme_bloc.dart';
import 'package:inklink/firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await _ensureFirebaseInitialized();
  final messagingService = MessagingServiceImpl();
  await LocalNotificationService.initialize(navigatorKey: appNavigatorKey);
  messagingService.onMessage.listen(
    LocalNotificationService.showFromRemoteMessage,
  );

  final themeRepository = ThemeRepositoryImpl();
  final initialThemeMode = await themeRepository.getThemeMode();

  final localDatabaseService = LocalDatabaseService();
  // Ensure DB drops tables or is initialized
  await localDatabaseService.database;

  runApp(
    // 0. Firebase Services (provide first, before repositories)
    MultiRepositoryProvider(
      providers: [
        // Firebase service abstractions
        RepositoryProvider<FirestoreService>(
          create: (context) => FirestoreServiceImpl(),
        ),
        RepositoryProvider<AuthService>(create: (context) => AuthServiceImpl()),
        RepositoryProvider<PresenceService>(
          create: (context) => PresenceServiceImpl(
            authService: context.read<AuthService>(),
            database: FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: dotenv.env['FIREBASE_RTDB_URL'],
            ),
          ),
        ),
        RepositoryProvider<CloudFunctionsService>(
          create: (context) => CloudFunctionsServiceImpl(),
        ),
        RepositoryProvider<MessagingService>.value(value: messagingService),
        // Other services
        RepositoryProvider<LocalDatabaseService>.value(
          value: localDatabaseService,
        ),
        // 1. Repositories (depend on Firebase services)
        RepositoryProvider<AuthRepository>(
          create: (context) => FirebaseAuthRepository(
            authService: context.read<AuthService>(),
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
        RepositoryProvider<FriendsRepository>(
          create: (context) => FriendsRepositoryImpl(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
            localDatabaseService: context.read<LocalDatabaseService>(),
          ),
        ),
        RepositoryProvider<ProfileRepository>(
          create: (context) => ProfileRepositoryImpl(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
            localDatabaseService: context.read<LocalDatabaseService>(),
          ),
        ),
        RepositoryProvider<BoardRepository>(
          create: (context) => FirestoreBoardRepository(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
            localDatabaseService: context.read<LocalDatabaseService>(),
          ),
        ),
        RepositoryProvider<CanvasSyncRepository>(
          create: (context) => FirestoreCanvasSyncRepository(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
            localDatabaseService: context.read<LocalDatabaseService>(),
          ),
        ),
        RepositoryProvider<SettingsRepository>(
          create: (context) => SettingsRepositoryImpl(
            localDatabaseService: context.read<LocalDatabaseService>(),
          ),
        ),
        RepositoryProvider<NotificationRepository>(
          create: (context) => NotificationRepositoryImpl(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
          ),
        ),
        RepositoryProvider<InvitationRepository>(
          create: (context) => InvitationRepositoryImpl(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
            localDatabaseService: context.read<LocalDatabaseService>(),
          ),
        ),
        // 2. Domain services (depend on repositories)
        RepositoryProvider<AuthSessionService>(
          create: (context) => AuthSessionServiceImpl(
            authRepository: context.read<AuthRepository>(),
            authService: context.read<AuthService>(),
            messagingService: context.read<MessagingService>(),
            localDatabaseService: context.read<LocalDatabaseService>(),
            presenceService: context.read<PresenceService>(),
          ),
        ),
        RepositoryProvider<FriendsService>(
          create: (context) => FriendsServiceImpl(
            friendsRepository: context.read<FriendsRepository>(),
            authService: context.read<AuthService>(),
            cloudFunctionsService: context.read<CloudFunctionsService>(),
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
        RepositoryProvider<InvitationService>(
          create: (context) => InvitationServiceImpl(
            invitationRepository: context.read<InvitationRepository>(),
            cloudFunctionsService: context.read<CloudFunctionsService>(),
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
        RepositoryProvider<BoardService>(
          create: (context) => BoardServiceImpl(
            boardRepository: context.read<BoardRepository>(),
            cloudFunctionsService: context.read<CloudFunctionsService>(),
          ),
        ),
        RepositoryProvider<ProfileService>(
          create: (context) => ProfileServiceImpl(
            profileRepository: context.read<ProfileRepository>(),
            authService: context.read<AuthService>(),
            cloudFunctionsService: context.read<CloudFunctionsService>(),
            friendsRepository: context.read<FriendsRepository>(),
            boardRepository: context.read<BoardRepository>(),
          ),
        ),
      ],
      // 3. BLoCs (depend on domain services/repositories)
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
            create: (context) => DashboardBloc(
              boardService: context.read<BoardService>(),
              profileService: context.read<ProfileService>(),
            ),
          ),
          BlocProvider(
            create: (context) =>
                AuthBloc(authService: context.read<AuthSessionService>())..add(
                  AuthCheckRequested(),
                ), // <--- Add this line to trigger check on start
          ),
          BlocProvider(
            create: (context) => FriendsBloc(
              friendsService: context
                  .read<FriendsService>(), // Reads from service provider
            ),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
    Firebase.app();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
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
