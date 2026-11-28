import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/composition/shared_canvas_dependencies.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cloud_functions_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/notification_preferences.dart';
import '../../domain/models/canvas/canvas_toolbar_action.dart';
import '../../domain/repositories/canvas/memory_crdt_local_store.dart';
import '../../domain/services/ai/ai_image_service.dart';
import '../../domain/services/board/board_service.dart';
import '../../domain/services/canvas/board_chat_service.dart';
import '../../domain/services/canvas/board_comments_service.dart';
import '../../domain/services/canvas/canvas_service.dart';
import '../../domain/services/history/board_history_service.dart';
import '../../domain/services/notification/notification_service.dart';
import '../../domain/services/settings/settings_service.dart';
import '../../domain/services/voice/voice_service.dart';
import '../../features/canvas/bloc/ai_image_bloc.dart';
import '../../features/canvas/bloc/canvas_bloc.dart';
import '../../features/canvas/view/canvas_screen.dart';
import '../../features/notifications/bloc/notifications_bloc.dart';
import '../../ui/theme/ink_theme.dart';
import 'web_board_repository.dart';
import 'web_canvas_support.dart';

/// Everything the mobile canvas needs on the web, backed by
/// [SharedCanvasDependencies] so mobile and web construct the exact same
/// shared canvas services from platform-supplied repositories.
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

/// Opens [boardId] in the mobile canvas with the light Ink theme and the
/// desktop browser layout (not the companion's glass look). Back returns
/// to the companion.
Route<void> buildWebCanvasRoute(
  WebCanvasServices services, {
  required String boardId,
}) {
  return MaterialPageRoute<void>(
    builder: (context) {
      // Always the light theme: white floating bars on the white board, as
      // in desktop whiteboard apps (the companion pages keep their own look).
      return Theme(
        data: InkTheme.light(),
        child: _WebCanvasPage(services: services, boardId: boardId),
      );
    },
  );
}

class _WebCanvasPage extends StatefulWidget {
  final WebCanvasServices services;
  final String boardId;

  const _WebCanvasPage({required this.services, required this.boardId});

  @override
  State<_WebCanvasPage> createState() => _WebCanvasPageState();
}

class _WebCanvasPageState extends State<_WebCanvasPage> {
  // Right-click opens the canvas menu, so the browser's own menu is off
  // while a board is open (and back on when you leave it).
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

  late final Future<
    ({
      String quality,
      bool compressionEnabled,
      List<CanvasToolbarAction> bottomBarActions,
    })
  >
  _settings = _loadSettings();

  // Same settings the phone's canvas route loads.
  Future<
    ({
      String quality,
      bool compressionEnabled,
      List<CanvasToolbarAction> bottomBarActions,
    })
  >
  _loadSettings() async {
    final s = widget.services.settingsService;
    return (
      quality: await s.getBoardPreviewQuality(),
      compressionEnabled: await s.getBoardPreviewCompressionEnabled(),
      bottomBarActions: await s.getBottomBarActions(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    return FutureBuilder(
      future: _settings,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => NotificationsBloc(
                notificationService: s.notificationService,
                notificationPreferences: NotificationPreferences(
                  prefs: s.prefs,
                ),
                boardService: s.boardService,
              )..add(const NotificationsLoadRequested()),
            ),
            BlocProvider(
              create: (_) => CanvasBloc(
                canvasService: s.canvasService,
                boardService: s.boardService,
                boardExportService: s.exportService,
                boardCommentsService: s.commentsService,
                boardChatService: s.chatService,
                voiceService: s.voiceService,
                historyService: s.historyService,
                currentUserId: s.authService.getCurrentUserId() ?? '',
                boardId: widget.boardId,
              )..add(CanvasInitializeCrdt(widget.boardId)),
            ),
            BlocProvider(
              create: (_) => AiImageBloc(aiImageService: s.aiImageService),
            ),
          ],
          child: CanvasScreen(
            boardId: widget.boardId,
            boardPreviewQuality: data?.quality ?? 'medium',
            boardPreviewCompressionEnabled: data?.compressionEnabled ?? true,
            initialBottomBarActions:
                data?.bottomBarActions ??
                CanvasToolbarAction.defaultBottomBarActions,
            onSaveBottomBarActions: s.settingsService.setBottomBarActions,
            historyService: s.historyService,
          ),
        );
      },
    );
  }
}
