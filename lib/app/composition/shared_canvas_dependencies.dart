import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/cloud_functions_service.dart';
import '../../core/services/firestore_service.dart';
import '../../domain/repositories/board/board_repository.dart';
import '../../domain/repositories/canvas/board_comments_repository.dart';
import '../../domain/repositories/canvas/board_comments_repository_impl.dart';
import '../../domain/repositories/canvas/canvas_sync_repository.dart';
import '../../domain/repositories/canvas/canvas_sync_repository_impl.dart';
import '../../domain/repositories/canvas/crdt_local_store.dart';
import '../../domain/repositories/history/board_history_repository.dart';
import '../../domain/repositories/history/board_history_repository_impl.dart';
import '../../domain/repositories/notification/notification_repository.dart';
import '../../domain/repositories/settings/settings_repository.dart';
import '../../domain/services/ai/ai_image_service.dart';
import '../../domain/services/board/board_service.dart';
import '../../domain/services/canvas/board_chat_service.dart';
import '../../domain/services/canvas/board_chat_service_impl.dart';
import '../../domain/services/canvas/board_comments_service.dart';
import '../../domain/services/canvas/board_comments_service_impl.dart';
import '../../domain/services/canvas/board_export_service.dart';
import '../../domain/services/canvas/canvas_service.dart';
import '../../domain/services/history/board_history_service.dart';
import '../../domain/services/history/board_history_service_impl.dart';
import '../../domain/services/notification/notification_service.dart';
import '../../domain/services/settings/settings_service.dart';
import '../../domain/services/voice/voice_service.dart';

/// Centralized registration of core Firebase wrappers, shared canvas
/// repositories, and shared domain services used by both mobile and web.
///
/// Platform-specific infrastructure ([BoardRepository], [CrdtLocalStore],
/// [SettingsRepository], [NotificationRepository], [VoiceService]) is injected
/// by each target's composition root so this module stays completely web-safe
/// (no Isar, `path_provider`, or Agora SDK imports).
class SharedCanvasDependencies {
  final SharedPreferences prefs;
  final AuthService authService;
  final FirestoreService firestoreService;
  final CloudFunctionsService cloudFunctionsService;

  // Platform-supplied & shared repositories
  final BoardRepository boardRepository;
  final CanvasSyncRepository canvasSyncRepository;
  final BoardCommentsRepository boardCommentsRepository;
  final BoardHistoryRepository boardHistoryRepository;
  final SettingsRepository settingsRepository;
  final NotificationRepository notificationRepository;

  // Shared domain services
  final CanvasService canvasService;
  final BoardService boardService;
  final BoardExportService exportService;
  final BoardCommentsService commentsService;
  final BoardChatService chatService;
  final BoardHistoryService historyService;
  final VoiceService voiceService;
  final AiImageService aiImageService;
  final SettingsService settingsService;
  final NotificationService notificationService;

  const SharedCanvasDependencies._({
    required this.prefs,
    required this.authService,
    required this.firestoreService,
    required this.cloudFunctionsService,
    required this.boardRepository,
    required this.canvasSyncRepository,
    required this.boardCommentsRepository,
    required this.boardHistoryRepository,
    required this.settingsRepository,
    required this.notificationRepository,
    required this.canvasService,
    required this.boardService,
    required this.exportService,
    required this.commentsService,
    required this.chatService,
    required this.historyService,
    required this.voiceService,
    required this.aiImageService,
    required this.settingsService,
    required this.notificationService,
  });

  factory SharedCanvasDependencies.create({
    required SharedPreferences prefs,
    required AuthService authService,
    required FirestoreService firestoreService,
    required CloudFunctionsService cloudFunctionsService,
    required BoardRepository boardRepository,
    required CrdtLocalStore crdtLocalStore,
    required SettingsRepository settingsRepository,
    required NotificationRepository notificationRepository,
    required VoiceService voiceService,
  }) {
    final canvasSyncRepository = FirestoreCanvasSyncRepository(
      authService: authService,
      store: crdtLocalStore,
    );
    final boardCommentsRepository = FirestoreBoardCommentsRepository(
      firestoreService: firestoreService,
    );
    final boardHistoryRepository = BoardHistoryRepositoryImpl(
      firestoreService: firestoreService,
      authService: authService,
    );

    return SharedCanvasDependencies._(
      prefs: prefs,
      authService: authService,
      firestoreService: firestoreService,
      cloudFunctionsService: cloudFunctionsService,
      boardRepository: boardRepository,
      canvasSyncRepository: canvasSyncRepository,
      boardCommentsRepository: boardCommentsRepository,
      boardHistoryRepository: boardHistoryRepository,
      settingsRepository: settingsRepository,
      notificationRepository: notificationRepository,
      canvasService: CanvasServiceImpl(
        boardRepository: boardRepository,
        syncRepository: canvasSyncRepository,
      ),
      boardService: BoardServiceImpl(
        boardRepository: boardRepository,
        cloudFunctionsService: cloudFunctionsService,
      ),
      exportService: const BoardExportServiceImpl(),
      commentsService: BoardCommentsServiceImpl(
        repository: boardCommentsRepository,
        authService: authService,
        cloudFunctionsService: cloudFunctionsService,
      ),
      chatService: BoardChatServiceImpl(authService: authService),
      historyService: BoardHistoryServiceImpl(
        authService: authService,
        cloudFunctionsService: cloudFunctionsService,
        historyRepository: boardHistoryRepository,
      ),
      voiceService: voiceService,
      aiImageService: AiImageServiceImpl(
        cloudFunctionsService: cloudFunctionsService,
      ),
      settingsService: SettingsServiceImpl(
        settingsRepository: settingsRepository,
      ),
      notificationService: NotificationServiceImpl(
        notificationRepository: notificationRepository,
      ),
    );
  }

  /// Exposes every shared wrapper, repository, and domain service as
  /// [RepositoryProvider]s for the widget tree.
  List<RepositoryProvider<dynamic>> toRepositoryProviders() => [
    RepositoryProvider<FirestoreService>.value(value: firestoreService),
    RepositoryProvider<AuthService>.value(value: authService),
    RepositoryProvider<CloudFunctionsService>.value(
      value: cloudFunctionsService,
    ),
    RepositoryProvider<BoardRepository>.value(value: boardRepository),
    RepositoryProvider<CanvasSyncRepository>.value(value: canvasSyncRepository),
    RepositoryProvider<BoardCommentsRepository>.value(
      value: boardCommentsRepository,
    ),
    RepositoryProvider<BoardHistoryRepository>.value(
      value: boardHistoryRepository,
    ),
    RepositoryProvider<SettingsRepository>.value(value: settingsRepository),
    RepositoryProvider<NotificationRepository>.value(
      value: notificationRepository,
    ),
    RepositoryProvider<BoardService>.value(value: boardService),
    RepositoryProvider<CanvasService>.value(value: canvasService),
    RepositoryProvider<BoardExportService>.value(value: exportService),
    RepositoryProvider<BoardCommentsService>.value(value: commentsService),
    RepositoryProvider<BoardChatService>.value(value: chatService),
    RepositoryProvider<BoardHistoryService>(
      create: (_) => historyService,
      dispose: (service) => service.dispose(),
    ),
    RepositoryProvider<VoiceService>.value(value: voiceService),
    RepositoryProvider<AiImageService>.value(value: aiImageService),
    RepositoryProvider<SettingsService>.value(value: settingsService),
    RepositoryProvider<NotificationService>.value(value: notificationService),
  ];
}
