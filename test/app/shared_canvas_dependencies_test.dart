import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/app/composition/shared_canvas_dependencies.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/core/services/cloud_functions_service.dart';
import 'package:inklink/core/services/firestore_service.dart';
import 'package:inklink/domain/repositories/canvas/memory_crdt_local_store.dart';
import 'package:inklink/web/canvas/web_board_repository.dart';
import 'package:inklink/web/canvas/web_canvas.dart';
import 'package:inklink/web/canvas/web_canvas_support.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth implements AuthService {
  @override
  User? getCurrentUser() => null;

  @override
  String? getCurrentUserId() => 'test-uid';

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;

  @override
  FirebaseAuth getInstance() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<EmailVerificationStatus> reloadAndCheckEmailVerified() async =>
      EmailVerificationStatus.unknown;

  @override
  Future<void> deleteAccount() async {}
}

class _FakeFirestore implements FirestoreService {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      throw UnimplementedError();

  @override
  FirebaseFirestore getInstance() => throw UnimplementedError();

  @override
  Future<void> enableNetwork() async {}

  @override
  Future<void> disableNetwork() async {}
}

class _FakeCloudFunctions implements CloudFunctionsService {
  @override
  FirebaseFunctions getInstance() => throw UnimplementedError();

  @override
  HttpsCallable httpsCallable(String functionName) =>
      throw UnimplementedError();
}

void main() {
  test(
    'SharedCanvasDependencies wires shared services from injected adapters',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = _FakeAuth();
      final firestore = _FakeFirestore();
      final functions = _FakeCloudFunctions();
      final boardRepo = WebBoardRepository(
        authService: auth,
        firestoreService: firestore,
      );
      final settingsRepo = WebSettingsRepository(prefs);
      final notificationRepo = WebNotificationRepository(
        authService: auth,
        firestoreService: firestore,
      );
      final voiceService = WebVoiceService();

      final shared = SharedCanvasDependencies.create(
        prefs: prefs,
        authService: auth,
        firestoreService: firestore,
        cloudFunctionsService: functions,
        boardRepository: boardRepo,
        crdtLocalStore: MemoryCrdtLocalStore(),
        settingsRepository: settingsRepo,
        notificationRepository: notificationRepo,
        voiceService: voiceService,
      );

      expect(shared.authService, same(auth));
      expect(shared.firestoreService, same(firestore));
      expect(shared.cloudFunctionsService, same(functions));
      expect(shared.boardRepository, same(boardRepo));
      expect(shared.settingsRepository, same(settingsRepo));
      expect(shared.notificationRepository, same(notificationRepo));
      expect(shared.voiceService, same(voiceService));
      expect(shared.toRepositoryProviders(), hasLength(19));

      final webCanvas = WebCanvasServices.fromShared(shared);
      expect(webCanvas.boardService, same(shared.boardService));
      expect(webCanvas.canvasService, same(shared.canvasService));
      expect(webCanvas.historyService, same(shared.historyService));

      shared.historyService.dispose();
    },
  );
}
