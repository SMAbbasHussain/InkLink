import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/composition/shared_canvas_dependencies.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/cloud_functions_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/utils/notification_preferences.dart';
import '../../../../domain/repositories/canvas/memory_crdt_local_store.dart';
import '../../../../domain/services/ai/ai_image_service.dart';
import '../../../../domain/services/board/board_service.dart';
import '../../../../domain/services/canvas/board_chat_service.dart';
import '../../../../domain/services/canvas/board_comments_service.dart';
import '../../../../domain/services/canvas/board_export_service.dart';
import '../../../../domain/services/canvas/canvas_service.dart';
import '../../../../domain/services/history/board_history_service.dart';
import '../../../../domain/services/notification/notification_service.dart';
import '../../../../domain/services/settings/settings_service.dart';
import '../../../../domain/services/voice/voice_service.dart';
import '../../../../features/canvas/view/canvas_route.dart';
import '../../../../features/notifications/bloc/notifications_bloc.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../domain/repositories/web_board_repository.dart';
import '../../../domain/repositories/web_notification_repository.dart';
import '../../../domain/repositories/web_settings_repository.dart';
import '../../../domain/services/web_voice_service.dart';

/// Web canvas service holder backed by [SharedCanvasDependencies] so mobile
/// and web construct the exact same shared canvas services from
/// platform-supplied repositories.
class WebCanvasServices {
  final SharedCanvasDependencies shared;

  const WebCanvasServices.fromShared(this.shared);

  AuthService get authService => shared.authService;
  SharedPreferences get prefs => shared.prefs;
  CanvasService get canvasService => shared.canvasService;
  BoardService get boardService => shared.boardService;
  BoardExportService get exportService => shared.exportService;
  BoardCommentsService get commentsService => shared.commentsService;
  BoardChatService get chatService => shared.chatService;
  BoardHistoryService get historyService => shared.historyService;
  VoiceService get voiceService => shared.voiceService;
  AiImageService get aiImageService => shared.aiImageService;
  SettingsService get settingsService => shared.settingsService;
  NotificationService get notificationService => shared.notificationService;

  /// Builds the services once Firebase is initialized.
  static Future<WebCanvasServices> create() async {
    final prefs = await SharedPreferences.getInstance();
    final AuthService auth = AuthServiceImpl();
    final FirestoreService firestore = FirestoreServiceImpl();
    final CloudFunctionsService functions = CloudFunctionsServiceImpl();
    final boardRepository = WebBoardRepository(
      authService: auth,
      firestoreService: firestore,
    );
    return WebCanvasServices.fromShared(
      SharedCanvasDependencies.create(
        prefs: prefs,
        authService: auth,
        firestoreService: firestore,
        cloudFunctionsService: functions,
        boardRepository: boardRepository,
        crdtLocalStore: MemoryCrdtLocalStore(),
        settingsRepository: WebSettingsRepository(prefs),
        notificationRepository: WebNotificationRepository(
          authService: auth,
          firestoreService: firestore,
        ),
        voiceService: WebVoiceService(),
      ),
    );
  }
}

/// Opens [boardId] in the shared [CanvasSessionView] wrapped with web-specific
/// concerns only: light desktop theme, browser context menu toggle, and the
/// web canvas provider scope.
Route<void> buildWebCanvasRoute(
  WebCanvasServices services, {
  required String boardId,
}) {
  return MaterialPageRoute<void>(
    builder: (context) => Theme(
      data: InkTheme.light(),
      child: _WebCanvasHost(services: services, boardId: boardId),
    ),
  );
}

class _WebCanvasHost extends StatefulWidget {
  final WebCanvasServices services;
  final String boardId;

  const _WebCanvasHost({required this.services, required this.boardId});

  @override
  State<_WebCanvasHost> createState() => _WebCanvasHostState();
}

class _WebCanvasHostState extends State<_WebCanvasHost> {
  // Right-click opens the canvas menu, so suppress the browser context menu
  // while a board is open and restore it on exit.
  @override
  void initState() {
    super.initState();
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
  }

  @override
  void dispose() {
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shared = widget.services.shared;
    return MultiRepositoryProvider(
      providers: [
        ...shared.toRepositoryProviders().where(
          // Avoid disposing the app-scoped historyService when leaving one board.
          (p) => p is! RepositoryProvider<BoardHistoryService>,
        ),
        RepositoryProvider<BoardHistoryService>.value(
          value: shared.historyService,
        ),
      ],
      child: BlocProvider(
        create: (_) => NotificationsBloc(
          notificationService: shared.notificationService,
          notificationPreferences: NotificationPreferences(prefs: shared.prefs),
          boardService: shared.boardService,
        )..add(const NotificationsLoadRequested()),
        child: CanvasSessionView(boardId: widget.boardId),
      ),
    );
  }
}
