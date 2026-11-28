import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/core/services/firestore_service.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/web/canvas/web_board_repository.dart';

class _FakeAuth implements AuthService {
  _FakeAuth({this.uid = 'web-user'});

  final String? uid;

  @override
  User? getCurrentUser() => null;

  @override
  String? getCurrentUserId() => uid;

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

  test('no BoardRepository member throws UnsupportedError any more', () {
    final source = File(
      'lib/web/canvas/web_board_repository.dart',
    ).readAsStringSync();
    expect(source, contains('implements BoardRepository'));
    expect(source.contains('UnsupportedError'), isFalse);
    expect(source.contains('_unsupported'), isFalse);
    expect(RegExp(r'noSuchMethod\s*\(').hasMatch(source), isFalse);
  });

  test(
    'board lifecycle calls reject empty ids before touching Firestore',
    () async {
      await repository.deleteBoard('  ');
      await expectLater(
        repository.joinBoard('  '),
        throwsA(predicate((error) => error.toString().contains('join code'))),
      );
    },
  );

  test('a signed-out user cannot create or copy a board', () async {
    final signedOut = WebBoardRepository(
      authService: _FakeAuth(uid: null),
      firestoreService: _FakeFirestore(),
    );
    await expectLater(
      signedOut.createNewBoard(
        name: 'New',
        visibility: Board.visibilityPrivate,
        privateJoinPolicy: Board.policyOwnerOnlyInvite,
        whoCanInvite: Board.inviteOwnerOnly,
        defaultLinkJoinRole: Board.roleViewer,
        tags: const [],
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      signedOut.duplicateBoard('b'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      signedOut.updateBoardTags('b', const ['x']),
      throwsA(isA<StateError>()),
    );
    expect(signedOut.currentUserId, isNull);
  });
}
