import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Thrown when a join code belongs to a private, invite-only board. The
/// request has already been forwarded to the board owner.
class BoardJoinApprovalRequiredException implements Exception {
  final String boardId;

  const BoardJoinApprovalRequiredException(this.boardId);

  @override
  String toString() =>
      'Join request sent to the board owner. You will be added once it is approved.';
}

/// Accepts a bare code, a pasted deep link (e.g. https://inklink.app/board/abc)
/// or a code with surrounding whitespace and returns just the board id.
String normalizeBoardJoinCode(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return '';

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
    final segments = uri.pathSegments.where((s) => s.trim().isNotEmpty);
    if (segments.isNotEmpty) value = segments.last;
  }

  value = value.split('?').first.split('#').first.trim();
  if (value.endsWith('/')) value = value.substring(0, value.length - 1);
  return value.trim();
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
    bool allowMembersToCopy = false,
    List<String> invitedUserIds,
    int inviteExpiryHours,
  });
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    bool? allowMembersToCopy,
  });
  Future<void> joinBoard(String boardId);
  Future<void> renameBoard(String boardId, String newName);
  Future<void> deleteBoard(String boardId);
  Future<void> archiveBoard(String boardId);
  Future<void> unarchiveBoard(String boardId);
  Future<String> duplicateBoard(String boardId, {String? customTitle});
  Future<void> updateBoardTags(String boardId, List<String> tags);
  Stream<List<BoardMember>> getBoardMembers(String boardId);
  Future<void> updateBoardMemberRole(
    String boardId,
    String targetUid,
    String role,
  );
  Future<void> removeBoardMember(String boardId, String targetUid);
  Future<void> leaveBoard(String boardId);
  Future<SendBoardInviteResult> sendBoardInvite({
    required String boardId,
    required String boardTitle,
    required List<String> invitedUserIds,
    required String targetRole,
    int inviteExpiryHours,
  });
  Future<PublicBoardsPage> getPublicBoards({
    String? tag,
    PublicBoardSort sort = PublicBoardSort.recent,
    dynamic lastDocCursor,
    int limit = 20,
  });
  Future<List<Board>> getRecommendedPublicBoards({
    required List<String> preferredTags,
    int limit = 10,
  });
  Future<void> requestBoardAccess({
    required String boardId,
    required String requestType,
    String? message,
  });
  Future<void> respondToBoardAccessRequest({
    required String boardId,
    required String requesterUid,
    required String notificationId,
    required String action,
    required String requestType,
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
    bool allowMembersToCopy = false,
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
      allowMembersToCopy: allowMembersToCopy,
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
    bool? allowMembersToCopy,
  }) async {
    await _boardRepository.updateBoardSettings(
      boardId: boardId,
      visibility: visibility,
      privateJoinPolicy: privateJoinPolicy,
      whoCanInvite: whoCanInvite,
      defaultLinkJoinRole: defaultLinkJoinRole,
      allowMembersToCopy: allowMembersToCopy,
    );

    try {
      await _cloudFunctionsService.httpsCallable('updateBoardSettings').call({
        'boardId': boardId,
        'visibility': visibility,
        'privateJoinPolicy': privateJoinPolicy,
        'whoCanInvite': whoCanInvite,
        'defaultLinkJoinRole': defaultLinkJoinRole,
        'allowMembersToCopy': ?allowMembersToCopy,
      });
    } catch (_) {
      // Local repository already updated.
    }
  }

  @override
  Future<void> joinBoard(String boardId) async {
    final joinCode = normalizeBoardJoinCode(boardId);
    if (joinCode.isEmpty) {
      throw Exception('Please enter a join code.');
    }

    try {
      await _cloudFunctionsService.httpsCallable('joinBoardByCode').call({
        'joinCode': joinCode,
      });
      await _boardRepository.ensureBoardCached(joinCode);
    } on FirebaseFunctionsException catch (e) {
      // Private boards default to invite-only. Instead of dead-ending the
      // user, turn the code into an access request the owner can approve.
      if (e.code == 'failed-precondition') {
        await requestBoardAccess(
          boardId: joinCode,
          requestType: 'join',
          message: 'Requested via join code.',
        );
        throw BoardJoinApprovalRequiredException(joinCode);
      }
      final message = e.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
      switch (e.code) {
        case 'permission-denied':
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
  Future<void> deleteBoard(String boardId) async {
    final resolvedBoardId = boardId.trim();
    if (resolvedBoardId.isEmpty) {
      return;
    }

    await _boardRepository.removeBoardSync(resolvedBoardId);

    try {
      await _cloudFunctionsService.httpsCallable('deleteBoard').call({
        'boardId': resolvedBoardId,
      });
    } on FirebaseFunctionsException catch (e) {
      // Already deleted (retry, another device, or a previous call that only
      // failed while purging subcollections): the local copy still has to go.
      if (e.code != 'not-found') {
        rethrow;
      }
    } finally {
      await _boardRepository.deleteBoard(resolvedBoardId);
    }
  }

  @override
  Future<void> archiveBoard(String boardId) {
    return _boardRepository.archiveBoard(boardId.trim());
  }

  @override
  Future<void> unarchiveBoard(String boardId) {
    return _boardRepository.unarchiveBoard(boardId.trim());
  }

  @override
  Future<String> duplicateBoard(String boardId, {String? customTitle}) {
    return _boardRepository.duplicateBoard(
      boardId.trim(),
      customTitle: customTitle,
    );
  }

  @override
  Future<void> updateBoardTags(String boardId, List<String> tags) {
    return _boardRepository.updateBoardTags(boardId.trim(), tags);
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
  Future<void> leaveBoard(String boardId) async {
    final uid = _boardRepository.currentUserId;
    if (uid == null || uid.isEmpty) {
      throw Exception('User not authenticated.');
    }
    await removeBoardMember(boardId, uid);
    await _boardRepository.removeBoardSync(boardId.trim());
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

  @override
  Future<PublicBoardsPage> getPublicBoards({
    String? tag,
    PublicBoardSort sort = PublicBoardSort.recent,
    dynamic lastDocCursor,
    int limit = 20,
  }) {
    return _boardRepository.getPublicBoards(
      tag: tag,
      sort: sort,
      lastDocCursor: lastDocCursor,
      limit: limit,
    );
  }

  @override
  Future<List<Board>> getRecommendedPublicBoards({
    required List<String> preferredTags,
    int limit = 10,
  }) {
    return _boardRepository.getRecommendedPublicBoards(
      preferredTags: preferredTags,
      limit: limit,
    );
  }

  static final Map<String, DateTime> _accessRequestCache = <String, DateTime>{};

  @override
  Future<void> requestBoardAccess({
    required String boardId,
    required String requestType,
    String? message,
  }) async {
    final cleanBoardId = boardId.trim();
    final cleanType = requestType.trim().toLowerCase();
    final cacheKey = 'access_req_${cleanBoardId}_$cleanType';
    final now = DateTime.now();

    // Check in-memory 5-minute cache
    final inMemoryLast = _accessRequestCache[cacheKey];
    if (inMemoryLast != null &&
        now.difference(inMemoryLast) < const Duration(minutes: 5)) {
      return;
    }

    // Check persistent 5-minute cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTimestamp = prefs.getInt(cacheKey);
      if (lastTimestamp != null) {
        final lastSent = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
        if (now.difference(lastSent) < const Duration(minutes: 5)) {
          _accessRequestCache[cacheKey] = lastSent;
          return;
        }
      }
    } catch (_) {}

    try {
      await _cloudFunctionsService.httpsCallable('requestBoardAccess').call({
        'boardId': cleanBoardId,
        'requestType': cleanType,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      });

      // Update 5-minute cache on success
      _accessRequestCache[cacheKey] = now;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(cacheKey, now.millisecondsSinceEpoch);
      } catch (_) {}
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to send access request.');
    } catch (e) {
      throw Exception('Failed to send access request. Please try again.');
    }
  }

  @override
  Future<void> respondToBoardAccessRequest({
    required String boardId,
    required String requesterUid,
    required String notificationId,
    required String action,
    required String requestType,
  }) async {
    try {
      await _cloudFunctionsService
          .httpsCallable('respondToBoardAccessRequest')
          .call({
            'boardId': boardId.trim(),
            'requesterUid': requesterUid.trim(),
            'notificationId': notificationId.trim(),
            'action': action.trim(),
            'requestType': requestType.trim(),
          });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to process request.');
    } catch (e) {
      throw Exception('Failed to process request. Please try again.');
    }
  }
}
