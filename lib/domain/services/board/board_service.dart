import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../models/board.dart';
import '../../repositories/board/board_repository.dart';

class CreateBoardResult {
  final String boardId;
  final List<String> unresolvedEmails;

  const CreateBoardResult({
    required this.boardId,
    this.unresolvedEmails = const [],
  });
}

class SendBoardInviteResult {
  final List<String> unresolvedEmails;

  const SendBoardInviteResult({this.unresolvedEmails = const []});
}

abstract class BoardService {
  Future<void> startBoardsSync();
  Future<void> stopBoardsSync();
  Stream<List<Board>> getOwnedBoards();
  Stream<List<Board>> getJoinedBoards();
  Stream<Board?> getBoardById(String boardId);
  Future<CreateBoardResult> createBoard({
    String? title,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    required String inviteTargetRole,
    required List<String> tags,
    List<String> invitedUserIds,
    int inviteExpiryHours,
  });
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
  });
  Future<void> joinBoard(String boardId);
  Future<void> renameBoard(String boardId, String newName);
  Future<void> deleteBoard(String boardId);
  Stream<List<BoardMember>> getBoardMembers(String boardId);
  Future<void> updateBoardMemberRole(
    String boardId,
    String targetUid,
    String role,
  );
  Future<void> removeBoardMember(String boardId, String targetUid);
  Future<SendBoardInviteResult> sendBoardInvite({
    required String boardId,
    required String boardTitle,
    required List<String> invitedUserIds,
    required String targetRole,
    int inviteExpiryHours,
  });
}

class BoardServiceImpl implements BoardService {
  final BoardRepository _boardRepository;
  final CloudFunctionsService _cloudFunctionsService;

  BoardServiceImpl({
    required BoardRepository boardRepository,
    required CloudFunctionsService cloudFunctionsService,
  }) : _boardRepository = boardRepository,
       _cloudFunctionsService = cloudFunctionsService;

  @override
  Future<void> startBoardsSync() => _boardRepository.startBoardsSync();

  @override
  Future<void> stopBoardsSync() => _boardRepository.stopBoardsSync();

  @override
  Stream<List<Board>> getOwnedBoards() => _boardRepository.getOwnedBoards();

  @override
  Stream<List<Board>> getJoinedBoards() => _boardRepository.getJoinedBoards();

  @override
  Stream<Board?> getBoardById(String boardId) {
    return _boardRepository.getBoardById(boardId);
  }

  @override
  Future<CreateBoardResult> createBoard({
    String? title,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    required String inviteTargetRole,
    required List<String> tags,
    List<String> invitedUserIds = const [],
    int inviteExpiryHours = 72,
  }) async {
    final resolvedTitle = (title == null || title.trim().isEmpty)
        ? 'Untitled Board'
        : title.trim();

    final boardId = await _boardRepository.createNewBoard(
      name: resolvedTitle,
      visibility: visibility,
      privateJoinPolicy: privateJoinPolicy,
      whoCanInvite: whoCanInvite,
      defaultLinkJoinRole: defaultLinkJoinRole,
      tags: tags,
      invitedUserIds: const [],
      inviteExpiryHours: inviteExpiryHours,
    );

    var unresolvedEmails = <String>[];

    if (invitedUserIds.isNotEmpty) {
      try {
        final response = await _cloudFunctionsService
            .httpsCallable('sendBoardInvite')
            .call({
              'boardId': boardId,
              'boardTitle': resolvedTitle,
              'invitedUserIds': invitedUserIds,
              'inviteExpiryHours': inviteExpiryHours,
              'targetRole': inviteTargetRole,
            });

        final data = response.data;
        if (data is Map) {
          unresolvedEmails = List<String>.from(
            data['unresolvedEmails'] ?? const <String>[],
          );
        }
      } catch (_) {
        // Board creation succeeds even if invite delivery fails.
      }
    }

    return CreateBoardResult(
      boardId: boardId,
      unresolvedEmails: unresolvedEmails,
    );
  }

  @override
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
  }) async {
    await _cloudFunctionsService.httpsCallable('updateBoardSettings').call({
      'boardId': boardId,
      'visibility': visibility,
      'privateJoinPolicy': privateJoinPolicy,
      'whoCanInvite': whoCanInvite,
      'defaultLinkJoinRole': defaultLinkJoinRole,
    });
  }

  @override
  Future<void> joinBoard(String boardId) async {
    try {
      await _cloudFunctionsService.httpsCallable('joinBoardByCode').call({
        'joinCode': boardId.trim(),
      });
      await _boardRepository.ensureBoardCached(boardId.trim());
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
      switch (e.code) {
        case 'permission-denied':
        case 'failed-precondition':
          throw Exception(
            'This board can only be joined by invitation from the owner.',
          );
        case 'not-found':
          throw Exception(
            'Board not found. Check the join code and try again.',
          );
        case 'invalid-argument':
          throw Exception('Invalid join code.');
        case 'unauthenticated':
          throw Exception('Please sign in and try again.');
        default:
          throw Exception('Unable to join board right now. Please try again.');
      }
    }
  }

  @override
  Future<void> renameBoard(String boardId, String newName) {
    return _boardRepository.renameBoard(boardId, newName);
  }

  @override
  Future<void> deleteBoard(String boardId) {
    final resolvedBoardId = boardId.trim();
    return _boardRepository
        .removeBoardSync(resolvedBoardId)
        .then(
          (_) => _cloudFunctionsService.httpsCallable('deleteBoard').call({
            'boardId': resolvedBoardId,
          }),
        )
        .then((_) {
          return _boardRepository.deleteBoard(resolvedBoardId);
        });
  }

  @override
  Stream<List<BoardMember>> getBoardMembers(String boardId) {
    return _boardRepository.getBoardMembers(boardId);
  }

  @override
  Future<void> updateBoardMemberRole(
    String boardId,
    String targetUid,
    String role,
  ) async {
    await _cloudFunctionsService.httpsCallable('updateBoardMemberRole').call({
      'boardId': boardId.trim(),
      'targetUid': targetUid.trim(),
      'role': role,
    });
  }

  @override
  Future<void> removeBoardMember(String boardId, String targetUid) async {
    await _cloudFunctionsService.httpsCallable('removeBoardMember').call({
      'boardId': boardId.trim(),
      'targetUid': targetUid.trim(),
    });
  }

  @override
  Future<SendBoardInviteResult> sendBoardInvite({
    required String boardId,
    required String boardTitle,
    required List<String> invitedUserIds,
    required String targetRole,
    int inviteExpiryHours = 72,
  }) async {
    final response = await _cloudFunctionsService
        .httpsCallable('sendBoardInvite')
        .call({
          'boardId': boardId.trim(),
          'boardTitle': boardTitle.trim(),
          'invitedUserIds': invitedUserIds,
          'inviteExpiryHours': inviteExpiryHours,
          'targetRole': targetRole,
        });

    final data = response.data;
    if (data is! Map) {
      return const SendBoardInviteResult();
    }

    return SendBoardInviteResult(
      unresolvedEmails: List<String>.from(
        data['unresolvedEmails'] ?? const <String>[],
      ),
    );
  }
}
