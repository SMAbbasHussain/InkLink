import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/local_database_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cloud_functions_service.dart';
import '../../core/services/crashlytics_service.dart';
import '../../core/services/data_prefetch_service.dart';
import '../../core/services/deep_link_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/utils/notification_preferences.dart';
import '../../domain/repositories/auth/auth_repository.dart';
import '../../domain/repositories/auth/auth_repository_impl.dart';
import '../../domain/repositories/board/board_repository_impl.dart';
import '../../domain/repositories/canvas/isar_crdt_local_store.dart';
import '../../domain/repositories/chat/chat_repository.dart';
import '../../domain/repositories/chat/chat_repository_impl.dart';
import '../../domain/repositories/friends/friends_repository.dart';
import '../../domain/repositories/friends/friends_repository_impl.dart';
import '../../domain/repositories/invitation/invitation_repository.dart';
import '../../domain/repositories/invitation/invitation_repository_impl.dart';
import '../../domain/repositories/notification/notification_repository_impl.dart';
import '../../domain/repositories/presence/presence_repository.dart';
import '../../domain/repositories/presence/presence_repository_impl.dart';
import '../../domain/repositories/profile/profile_repository.dart';
import '../../domain/repositories/profile/profile_repository_impl.dart';
import '../../domain/repositories/settings/settings_repository_impl.dart';
import '../../domain/repositories/theme/theme_repository_impl.dart';
import '../../domain/repositories/workspace/workspace_repository.dart';
import '../../domain/repositories/workspace/workspace_repository_impl.dart';
import '../../domain/services/auth/auth_session_service.dart';
import '../../domain/services/chat/agora_chat_service.dart';
import '../../domain/services/chat/chat_service.dart';
import '../../domain/services/friends/friends_service.dart';
import '../../domain/services/invitation/invitation_service.dart';
import '../../domain/services/presence/presence_service.dart';
import '../../domain/services/profile/profile_service.dart';
import '../../domain/services/theme/theme_service.dart';
import '../../domain/services/voice/voice_service_impl.dart';
import '../../domain/services/workspace/workspace_service.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';
import '../../features/board_invitations/bloc/board_invitations_bloc.dart';
import '../../features/dashboard/bloc/dashboard_bloc.dart';
import '../../features/friends/bloc/friends_bloc.dart';
import '../../features/navigation/bloc/nav_bloc.dart';
import '../../features/notifications/bloc/notifications_bloc.dart';
import '../../features/theme/bloc/theme_bloc.dart';
import '../../features/workspaces/bloc/workspace_bloc.dart';
import '../bootstrap/firebase_bootstrap.dart';
import 'shared_canvas_dependencies.dart';

/// Mobile-only bootstrap and dependency registration.
///
/// Wires mobile infrastructure (Isar, Firebase RTDB, Crashlytics, FCM, local
/// notifications, deep links, Agora Chat & Voice) alongside the shared canvas
/// services built by [SharedCanvasDependencies]. Never imported by the web
/// entry point.
class MobileDependencies {
  final SharedCanvasDependencies shared;
  final ThemeMode initialThemeMode;
  final MessagingService messagingService;
  final ThemeService themeService;
  final LocalDatabaseService localDatabaseService;

  // Mobile-only repositories
  final AuthRepository authRepository;
  final PresenceRepository presenceRepository;
  final FriendsRepository friendsRepository;
  final ProfileRepository profileRepository;
  final InvitationRepository invitationRepository;
  final WorkspaceRepository workspaceRepository;
  final ChatRepository chatRepository;

  // Mobile-only domain services
  final PresenceService presenceService;
  final AuthSessionService authSessionService;
  final FriendsService friendsService;
  final InvitationService invitationService;
  final ChatService chatService;
  final WorkspaceService workspaceService;
  final ProfileService profileService;
  final DataPrefetchService dataPrefetchService;

  const MobileDependencies._({
    required this.shared,
    required this.initialThemeMode,
    required this.messagingService,
    required this.themeService,
    required this.localDatabaseService,
    required this.authRepository,
    required this.presenceRepository,
    required this.friendsRepository,
    required this.profileRepository,
    required this.invitationRepository,
    required this.workspaceRepository,
    required this.chatRepository,
    required this.presenceService,
    required this.authSessionService,
    required this.friendsService,
    required this.invitationService,
    required this.chatService,
    required this.workspaceService,
    required this.profileService,
    required this.dataPrefetchService,
  });

  /// Runs the mobile startup sequence in its exact initialization order and
  /// constructs all mobile + shared dependencies.
  static Future<MobileDependencies> bootstrap({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    await ensureFirebaseInitialized();
    CrashlyticsService.instance.initialize();

    final rtdbUrl = dotenv.env['FIREBASE_RTDB_URL'];
    final FirebaseDatabase rtdb = (rtdbUrl != null && rtdbUrl.isNotEmpty)
        ? FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: rtdbUrl,
          )
        : FirebaseDatabase.instanceFor(app: Firebase.app());

    final messagingService = MessagingServiceImpl();
    await LocalNotificationService.initialize(navigatorKey: navigatorKey);
    DeepLinkService.instance.initialize(navigatorKey: navigatorKey);
    messagingService.onMessage.listen(
      LocalNotificationService.showFromRemoteMessage,
    );

    final themeRepository = ThemeRepositoryImpl();
    final themeService = ThemeServiceImpl(themeRepository: themeRepository);
    final initialThemeMode = await themeService.getThemeMode();

    final localDatabaseService = LocalDatabaseService();
    await localDatabaseService.database;

    final authService = AuthServiceImpl();
    final firestoreService = FirestoreServiceImpl();
    final cloudFunctionsService = CloudFunctionsServiceImpl();

    final boardRepository = FirestoreBoardRepository(
      firestoreService: firestoreService,
      authService: authService,
      localDatabaseService: localDatabaseService,
    );
    final settingsRepository = SettingsRepositoryImpl(
      localDatabaseService: localDatabaseService,
      sharedPreferences: sharedPreferences,
    );
    final notificationRepository = NotificationRepositoryImpl(
      firestoreService: firestoreService,
      authService: authService,
      localDatabaseService: localDatabaseService,
    );
    final voiceService = VoiceServiceImpl(authService: authService);

    final shared = SharedCanvasDependencies.create(
      prefs: sharedPreferences,
      authService: authService,
      firestoreService: firestoreService,
      cloudFunctionsService: cloudFunctionsService,
      boardRepository: boardRepository,
      crdtLocalStore: IsarCrdtLocalStore(localDatabaseService),
      settingsRepository: settingsRepository,
      notificationRepository: notificationRepository,
      voiceService: voiceService,
    );

    final authRepository = FirebaseAuthRepository(
      authService: authService,
      firestoreService: firestoreService,
      database: rtdb,
    );
    final presenceRepository = FirebasePresenceRepository(database: rtdb);
    final friendsRepository = FriendsRepositoryImpl(
      firestoreService: firestoreService,
      authService: authService,
      localDatabaseService: localDatabaseService,
    );
    final profileRepository = ProfileRepositoryImpl(
      firestoreService: firestoreService,
      authService: authService,
      localDatabaseService: localDatabaseService,
    );
    final invitationRepository = InvitationRepositoryImpl(
      firestoreService: firestoreService,
      authService: authService,
      localDatabaseService: localDatabaseService,
    );
    final workspaceRepository = FirestoreWorkspaceRepository(
      firestoreService: firestoreService,
      authService: authService,
      localDatabaseService: localDatabaseService,
    );
    final chatRepository = ChatRepositoryImpl(
      localDatabaseService: localDatabaseService,
    );

    final presenceService = PresenceServiceImpl(
      presenceRepository: presenceRepository,
      authService: authService,
    );
    final authSessionService = AuthSessionServiceImpl(
      authRepository: authRepository,
      authService: authService,
      messagingService: messagingService,
      localDatabaseService: localDatabaseService,
      presenceService: presenceService,
      canvasSyncRepository: shared.canvasSyncRepository,
      cloudFunctionsService: cloudFunctionsService,
    );
    final friendsService = FriendsServiceImpl(
      friendsRepository: friendsRepository,
      authService: authService,
      cloudFunctionsService: cloudFunctionsService,
    );
    final invitationService = InvitationServiceImpl(
      invitationRepository: invitationRepository,
      boardRepository: boardRepository,
      cloudFunctionsService: cloudFunctionsService,
    );
    final chatService = AgoraChatServiceImpl(
      chatRepository: chatRepository,
      authService: authService,
      presenceService: presenceService,
      pushTokenProvider: messagingService.getToken,
    )..initialize();
    final workspaceService = WorkspaceServiceImpl(
      repository: workspaceRepository,
      cloudFunctionsService: cloudFunctionsService,
    );
    final profileService = ProfileServiceImpl(
      profileRepository: profileRepository,
      authService: authService,
      cloudFunctionsService: cloudFunctionsService,
      friendsRepository: friendsRepository,
    );
    final dataPrefetchService = DataPrefetchService(
      boardRepository: boardRepository,
      friendsRepository: friendsRepository,
      invitationRepository: invitationRepository,
    );

    return MobileDependencies._(
      shared: shared,
      initialThemeMode: initialThemeMode,
      messagingService: messagingService,
      themeService: themeService,
      localDatabaseService: localDatabaseService,
      authRepository: authRepository,
      presenceRepository: presenceRepository,
      friendsRepository: friendsRepository,
      profileRepository: profileRepository,
      invitationRepository: invitationRepository,
      workspaceRepository: workspaceRepository,
      chatRepository: chatRepository,
      presenceService: presenceService,
      authSessionService: authSessionService,
      friendsService: friendsService,
      invitationService: invitationService,
      chatService: chatService,
      workspaceService: workspaceService,
      profileService: profileService,
      dataPrefetchService: dataPrefetchService,
    );
  }

  List<RepositoryProvider<dynamic>> buildRepositoryProviders() => [
    ...shared.toRepositoryProviders(),
    RepositoryProvider<MessagingService>.value(value: messagingService),
    RepositoryProvider<ThemeService>.value(value: themeService),
    RepositoryProvider<LocalDatabaseService>.value(value: localDatabaseService),
    RepositoryProvider<AuthRepository>.value(value: authRepository),
    RepositoryProvider<PresenceRepository>.value(value: presenceRepository),
    RepositoryProvider<FriendsRepository>.value(value: friendsRepository),
    RepositoryProvider<ProfileRepository>.value(value: profileRepository),
    RepositoryProvider<InvitationRepository>.value(value: invitationRepository),
    RepositoryProvider<WorkspaceRepository>.value(value: workspaceRepository),
    RepositoryProvider<ChatRepository>.value(value: chatRepository),
    RepositoryProvider<PresenceService>.value(value: presenceService),
    RepositoryProvider<AuthSessionService>.value(value: authSessionService),
    RepositoryProvider<FriendsService>.value(value: friendsService),
    RepositoryProvider<InvitationService>.value(value: invitationService),
    RepositoryProvider<ChatService>.value(value: chatService),
    RepositoryProvider<WorkspaceService>.value(value: workspaceService),
    RepositoryProvider<ProfileService>.value(value: profileService),
    RepositoryProvider<DataPrefetchService>.value(value: dataPrefetchService),
  ];

  List<BlocProvider<dynamic>> buildBlocProviders() => [
    BlocProvider<ThemeBloc>(
      create: (_) =>
          ThemeBloc(themeService: themeService, initialMode: initialThemeMode)
            ..add(LoadTheme()),
    ),
    BlocProvider<NavBloc>(create: (_) => NavBloc()),
    BlocProvider<DashboardBloc>(
      create: (_) => DashboardBloc(
        boardService: shared.boardService,
        profileService: profileService,
      ),
    ),
    BlocProvider<AuthBloc>(
      create: (_) =>
          AuthBloc(authService: authSessionService)..add(AuthCheckRequested()),
    ),
    BlocProvider<FriendsBloc>(
      create: (_) => FriendsBloc(friendsService: friendsService),
    ),
    BlocProvider<NotificationsBloc>(
      create: (_) => NotificationsBloc(
        notificationService: shared.notificationService,
        notificationPreferences: NotificationPreferences(prefs: shared.prefs),
        boardService: shared.boardService,
      )..add(const NotificationsLoadRequested()),
    ),
    BlocProvider<BoardInvitationsBloc>(
      create: (_) =>
          BoardInvitationsBloc(invitationService: invitationService)
            ..add(const BoardInvitationsLoadRequested()),
    ),
    BlocProvider<WorkspaceBloc>(
      create: (_) => WorkspaceBloc(workspaceService: workspaceService),
    ),
  ];
}
