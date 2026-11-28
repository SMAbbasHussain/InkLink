import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/semantics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/cloud_functions_service.dart';
import '../../core/services/firestore_service.dart';
import '../../domain/repositories/canvas/memory_crdt_local_store.dart';
import '../../web/canvas/web_canvas.dart';
import '../../web/core/web_location_parser.dart';
import '../../web/domain/repositories/firebase_web_companion_repository.dart';
import '../../web/domain/repositories/web_board_repository.dart';
import '../../web/domain/repositories/web_notification_repository.dart';
import '../../web/domain/repositories/web_settings_repository.dart';
import '../../web/domain/services/web_companion_service.dart';
import '../../web/domain/services/web_voice_service.dart';
import '../../web/screens/web_shell_nav.dart';
import '../bootstrap/firebase_bootstrap.dart';
import 'shared_canvas_dependencies.dart';

/// Web-only bootstrap and dependency registration.
///
/// Builds a single set of Firebase wrappers (`AuthService`, `FirestoreService`,
/// `CloudFunctionsService`) and `SharedPreferences`, feeds web-safe repository
/// implementations into [SharedCanvasDependencies], and constructs
/// [WebCompanionService] reusing those exact same repositories and shared
/// [BoardService]. Never imports Isar, `path_provider`, Agora, Crashlytics, or
/// mobile notification plugins.
class WebDependencies {
  final SharedCanvasDependencies shared;
  final WebCanvasServices canvasServices;
  final WebCompanionService companionService;
  final WebSection initialSection;
  final String? initialBoardId;

  const WebDependencies._({
    required this.shared,
    required this.canvasServices,
    required this.companionService,
    required this.initialSection,
    required this.initialBoardId,
  });

  static Future<WebDependencies> bootstrap() async {
    // Flutter web keeps the accessibility tree off until requested; enable it
    // upfront so screen readers and keyboard users see real labels immediately.
    SemanticsBinding.instance.ensureSemantics();
    await loadAppEnvironment(ignoreErrors: false);
    await ensureFirebaseInitialized();

    final prefs = await SharedPreferences.getInstance();
    final AuthService auth = AuthServiceImpl();
    final FirestoreService firestore = FirestoreServiceImpl();
    final CloudFunctionsService functions = CloudFunctionsServiceImpl();

    final boardRepository = WebBoardRepository(
      authService: auth,
      firestoreService: firestore,
    );
    final notificationRepository = WebNotificationRepository(
      authService: auth,
      firestoreService: firestore,
    );
    final shared = SharedCanvasDependencies.create(
      prefs: prefs,
      authService: auth,
      firestoreService: firestore,
      cloudFunctionsService: functions,
      boardRepository: boardRepository,
      crdtLocalStore: MemoryCrdtLocalStore(),
      settingsRepository: WebSettingsRepository(prefs),
      notificationRepository: notificationRepository,
      voiceService: WebVoiceService(),
    );

    final companionData = FirebaseWebCompanionRepository(
      authService: auth,
      firestoreService: firestore,
      boardRepository: boardRepository,
      notificationRepository: notificationRepository,
    );
    final companionService = WebCompanionServiceImpl(
      data: companionData,
      boardService: shared.boardService,
      cloudFunctionsService: functions,
    );

    final location = parseWebLocation(
      PlatformDispatcher.instance.defaultRouteName,
    );
    final section = WebSection.values
        .where((s) => s.name == location.sectionName)
        .firstOrNull;

    return WebDependencies._(
      shared: shared,
      canvasServices: WebCanvasServices.fromShared(shared),
      companionService: companionService,
      initialSection: section ?? WebSection.boards,
      initialBoardId: location.boardId,
    );
  }
}
