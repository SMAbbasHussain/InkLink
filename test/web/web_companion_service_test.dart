import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/services/cloud_functions_service.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/board/board_service.dart';
import 'package:inklink/web/data/web_account.dart';
import 'package:inklink/web/data/web_companion_repository.dart';
import 'package:inklink/web/domain/web_companion_service.dart';

class _StubRepository implements WebCompanionRepository {
  String? lastRenamedId;
  String? lastRenamedName;
  WebAccount? user;

  @override
  WebAccount? get currentUser => user;

  @override
  Future<void> renameBoard(String boardId, String newName) async {
    lastRenamedId = boardId;
    lastRenamedName = newName;
  }

  @override
  Future<String> createBoard({
    required String name,
    String visibility = Board.visibilityPrivate,
    String privateJoinPolicy = Board.policyOwnerOnlyInvite,
    String whoCanInvite = Board.inviteOwnerOnly,
    String defaultLinkJoinRole = Board.roleViewer,
    List<String> tags = const [],
    bool allowMembersToCopy = false,
  }) async => 'board-123';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubBoardService implements BoardService {
  String? deletedBoardId;
  bool? pausedValue;

  @override
  Future<void> deleteBoard(String boardId) async {
    deletedBoardId = boardId;
  }

  @override
  Future<void> setBoardPaused(String boardId, {required bool isPaused}) async {
    pausedValue = isPaused;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedCloudFunctionsService implements CloudFunctionsService {
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      throw StateError('Should not invoke Cloud Function $name');

  @override
  FirebaseFunctions getInstance() =>
      throw StateError('Should not access FirebaseFunctions');
}

void main() {
  late _StubRepository repo;
  late _StubBoardService boardService;
  late WebCompanionServiceImpl service;

  setUp(() {
    repo = _StubRepository();
    boardService = _StubBoardService();
    service = WebCompanionServiceImpl(
      data: repo,
      boardService: boardService,
      cloudFunctionsService: _UnusedCloudFunctionsService(),
    );
  });

  test('validates empty profile photo bytes before calling backend', () async {
    await expectLater(
      service.uploadProfilePhoto(Uint8List(0), filename: 'avatar.png'),
      throwsA(predicate((e) => e.toString().contains('could not be read'))),
    );
  });

  test(
    'validates empty workspace invite list before calling backend',
    () async {
      await expectLater(
        service.inviteToWorkspace(
          workspaceId: 'w-product',
          userIds: const ['   ', ''],
        ),
        throwsA(
          predicate((e) => e.toString().contains('Choose someone to invite')),
        ),
      );
    },
  );

  test('requires signed-in user before deleting account', () async {
    await expectLater(
      service.deleteAccount(),
      throwsA(predicate((e) => e.toString().contains('sign in'))),
    );
  });

  test(
    'delegates board reads/writes to repository and privileged actions to BoardService',
    () async {
      final boardId = await service.createBoard(name: 'Architecture Notes');
      expect(boardId, 'board-123');

      await service.renameBoard(boardId, 'Architecture Review');
      expect(repo.lastRenamedId, 'board-123');
      expect(repo.lastRenamedName, 'Architecture Review');

      await service.setBoardPaused(boardId, paused: true);
      expect(boardService.pausedValue, isTrue);

      await service.deleteBoard(boardId);
      expect(boardService.deletedBoardId, 'board-123');
    },
  );
}
