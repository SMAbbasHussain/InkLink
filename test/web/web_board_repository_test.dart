import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/core/services/firestore_service.dart';
import 'package:inklink/web/canvas/web_board_repository.dart';

class _FakeAuth implements AuthService {
  @override
  User? getCurrentUser() => null;

  @override
  String? getCurrentUserId() => 'web-user';

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
      throw UnimplementedError('not used by these tests');

  @override
  FirebaseFirestore getInstance() => throw UnimplementedError();

  @override
  HttpsCallable getHttpsCallable(String name) => throw UnimplementedError();

  @override
  Future<void> enableNetwork() async {}

  @override
  Future<void> disableNetwork() async {}
}

void main() {
  late WebBoardRepository repository;

  setUp(() {
    repository = WebBoardRepository(
      authService: _FakeAuth(),
      firestoreService: _FakeFirestore(),
    );
  });

  test('the canvas subset still works without touching Firestore', () async {
    expect(repository.currentUserId, 'web-user');

    // An empty id never reaches Firestore.
    expect(await repository.getBoardById('   ').single, isNull);

    await repository.activateBoard('b');
    await repository.deactivateBoard();
    await repository.ensureBoardCached('b');
    await repository.removeBoardSync('b');
    await repository.saveBoardPreview('b', Uint8List(0));
    expect(await repository.watchBoardPreview('b').single, isNull);
    await repository.startBoardsSync();
    await repository.stopBoardsSync();
  });

  test('every other BoardRepository member throws UnsupportedError', () {
    final calls = <String, void Function()>{
      'countBoardsForUser': () => repository.countBoardsForUser('u'),
      'getOwnedBoards': repository.getOwnedBoards,
      'getJoinedBoards': repository.getJoinedBoards,
      'createNewBoard': () => repository.createNewBoard(
        visibility: 'public',
        privateJoinPolicy: 'open',
        whoCanInvite: 'owner',
        defaultLinkJoinRole: 'viewer',
        tags: const [],
      ),
      'joinBoard': () => repository.joinBoard('b'),
      'deleteBoard': () => repository.deleteBoard('b'),
      'archiveBoard': () => repository.archiveBoard('b'),
      'unarchiveBoard': () => repository.unarchiveBoard('b'),
      'setBoardPaused': () => repository.setBoardPaused('b', isPaused: true),
      'duplicateBoard': () => repository.duplicateBoard('b'),
      'updateBoardTags': () => repository.updateBoardTags('b', const []),
      'updateBoardSettings': () => repository.updateBoardSettings(
        boardId: 'b',
        visibility: 'public',
        privateJoinPolicy: 'open',
        whoCanInvite: 'owner',
        defaultLinkJoinRole: 'viewer',
      ),
      'getPublicBoards': repository.getPublicBoards,
      'getRecommendedPublicBoards': () =>
          repository.getRecommendedPublicBoards(preferredTags: const []),
    };

    for (final entry in calls.entries) {
      expect(
        entry.value,
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains(entry.key),
          ),
        ),
        reason: entry.key,
      );
    }
  });
}
