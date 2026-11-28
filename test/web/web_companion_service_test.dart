import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/web/domain/web_companion_service.dart';
import 'package:inklink/web/preview/sample_web_repository.dart';

void main() {
  late SampleWebCompanionRepository sampleRepo;
  late WebCompanionService service;

  setUp(() {
    sampleRepo = SampleWebCompanionRepository();
    service = WebCompanionServiceImpl.fromRepository(sampleRepo);
  });

  test('validates empty profile photo bytes before touching backend', () async {
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

  test(
    'delegates sample-mode board and workspace operations cleanly',
    () async {
      final boardId = await service.createBoard(name: 'Architecture Notes');
      final boards = await service.watchMyBoards().first;
      expect(boards.any((b) => b.id == boardId), isTrue);

      await service.renameBoard(boardId, 'Architecture Review');
      final renamed = await service.watchMyBoards().first;
      expect(
        renamed.firstWhere((b) => b.id == boardId).title,
        'Architecture Review',
      );
    },
  );
}
