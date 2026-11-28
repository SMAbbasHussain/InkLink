import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import '../../core/services/cloud_functions_service.dart';
import '../../domain/models/board.dart';
import '../../domain/models/friends/friend.dart';
import '../../domain/models/friends/friend_request.dart';
import '../../domain/models/invitation/board_invitation.dart';
import '../../domain/models/notification/in_app_notification.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/workspace.dart';
import '../../domain/services/board/board_rules.dart';
import '../../domain/services/board/board_service.dart';
import '../data/web_account.dart';
import '../data/web_account_settings.dart';
import '../data/web_companion_repository.dart';

/// Domain service contract for the web companion.
///
/// Owns business validation and privileged Cloud Function orchestration
/// (reusing the shared [BoardService] for board mutations) while delegating
/// pure data access to [WebCompanionDataRepository].
abstract class WebCompanionService {
  // Auth
  Stream<WebAccount?> get authChanges;
  WebAccount? get currentUser;
  Future<void> signInWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> resendVerificationEmail();
  Future<bool> reloadEmailVerified();
  Future<void> signOut();
  Future<void> deleteAccount();

  // Profile & account settings
  Stream<UserModel?> watchMyProfile();
  Future<void> updateProfile({required String name, required String bio});
  Future<void> uploadProfilePhoto(Uint8List bytes, {required String filename});
  Stream<WebAccountSettings> watchAccountSettings();
  Future<void> updatePrivacySettings({
    required bool isProfilePublic,
    required bool showOnlineStatus,
    required bool showEmail,
  });
  Future<void> updatePreferredTags(List<String> tags);

  // Boards
  Stream<List<Board>> watchMyBoards();
  Future<List<Board>> loadPublicBoards({int limit = 40});
  Future<String> createBoard({
    required String name,
    String visibility = Board.visibilityPrivate,
    String privateJoinPolicy = Board.policyOwnerOnlyInvite,
    String whoCanInvite = Board.inviteOwnerOnly,
    String defaultLinkJoinRole = Board.roleViewer,
    List<String> tags = const [],
    bool allowMembersToCopy = false,
  });
  Future<void> joinBoard(String boardIdOrCode);
  Future<void> renameBoard(String boardId, String newName);
  Future<void> setBoardArchived(String boardId, {required bool archived});
  Future<void> setBoardPaused(String boardId, {required bool paused});
  Future<void> deleteBoard(String boardId);
  Future<void> duplicateBoard(String boardId, {String? customTitle});
  Future<void> updateBoardTags(String boardId, List<String> tags);
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    bool? allowMembersToCopy,
  });

  // Workspaces
  Stream<List<Workspace>> watchMyWorkspaces();
  Stream<List<Board>> watchWorkspaceBoards(String workspaceId);
  Future<String> createWorkspace({
    required String name,
    required String description,
  });
  Future<void> updateWorkspace({
    required String workspaceId,
    String? name,
    String? description,
  });
  Future<void> addBoardToWorkspace({
    required String workspaceId,
    required String boardId,
  });
  Future<void> removeBoardFromWorkspace({
    required String workspaceId,
    required String boardId,
  });
  Stream<List<WorkspaceMember>> watchWorkspaceMembers(String workspaceId);
  Future<void> updateWorkspaceMemberRole({
    required String workspaceId,
    required String memberUid,
    required String role,
  });
  Future<void> removeWorkspaceMember({
    required String workspaceId,
    required String memberUid,
  });
  Future<void> inviteToWorkspace({
    required String workspaceId,
    required List<String> userIds,
  });
  Future<void> leaveWorkspace(String workspaceId);
  Future<void> deleteWorkspace(String workspaceId);

  // Invites
  Stream<List<BoardInvitation>> watchBoardInvites();
  Stream<List<WorkspaceInvite>> watchWorkspaceInvites();
  Future<void> acceptBoardInvite(String inviteId);
  Future<void> declineBoardInvite(String inviteId);
  Future<void> acceptWorkspaceInvite(String inviteId);
  Future<void> declineWorkspaceInvite(String inviteId);

  // Friends
  Stream<List<FriendRequest>> watchIncomingFriendRequests();
  Stream<List<Friend>> watchFriends();
  Future<void> acceptFriendRequest(String requestId);
  Future<void> declineFriendRequest(String requestId);
  Future<List<Friend>> searchUsersByEmail(String email);
  Future<void> sendFriendRequest(String targetUid);
  Future<void> unfriend(String targetUid);
  Stream<List<Friend>> watchBlockedUsers();
  Future<void> blockUser(String targetUid);
  Future<void> unblockUser(String targetUid);

  // Notifications
  Stream<List<InAppNotification>> watchNotifications();
  Future<void> deleteNotification(String notificationId);
  Stream<Set<String>> watchReadNotificationIds();
  Future<void> markNotificationRead(String id);
  Future<void> markAllNotificationsRead(Iterable<String> ids);
  Stream<List<InAppNotification>> watchNotificationsWithReadState();
}

/// Default domain-service implementation for the web companion.
///
/// - In production, delegates Firestore/Auth/SharedPreferences access to
///   [WebCompanionDataRepository], board lifecycle orchestration to the shared
///   [BoardService], and remaining privileged actions to
///   [CloudFunctionsService].
/// - In preview/test mode ([WebCompanionServiceImpl.fromRepository]), adapts an
///   in-memory [WebCompanionRepository] cleanly with zero Firebase dependencies.
class WebCompanionServiceImpl implements WebCompanionService {
  final WebCompanionDataRepository _data;
  final WebCompanionRepository? _sampleRepo;
  final BoardService? _boardService;
  final CloudFunctionsService? _functions;

  WebCompanionServiceImpl({
    required this._data,
    required this._boardService,
    required CloudFunctionsService cloudFunctionsService,
  }) : _sampleRepo = null,
       _functions = cloudFunctionsService;

  WebCompanionServiceImpl.fromRepository(WebCompanionRepository repository)
    : _data = repository,
      _sampleRepo = repository,
      _boardService = null,
      _functions = null;

  // ── Auth ────────────────────────────────────────────────────────────────

  @override
  Stream<WebAccount?> get authChanges => _data.authChanges;

  @override
  WebAccount? get currentUser => _data.currentUser;

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _data.signInWithEmail(email, password);

  @override
  Future<void> signInWithGoogle() => _data.signInWithGoogle();

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) => _data.signUpWithEmail(name: name, email: email, password: password);

  @override
  Future<void> sendPasswordReset(String email) =>
      _data.sendPasswordReset(email);

  @override
  Future<void> resendVerificationEmail() => _data.resendVerificationEmail();

  @override
  Future<bool> reloadEmailVerified() => _data.reloadEmailVerified();

  @override
  Future<void> signOut() => _data.signOut();

  @override
  Future<void> deleteAccount() async {
    if (_sampleRepo != null) {
      await _sampleRepo.deleteAccount();
      return;
    }
    if (currentUser == null) throw 'Please sign in again.';
    await _callData('deleteUserAccount', const {});
    await _data.signOut();
  }

  // ── Profile & Account Settings ──────────────────────────────────────────

  @override
  Stream<UserModel?> watchMyProfile() => _data.watchMyProfile();

  @override
  Future<void> updateProfile({required String name, required String bio}) =>
      _data.updateProfile(name: name, bio: bio);

  @override
  Future<void> uploadProfilePhoto(
    Uint8List bytes, {
    required String filename,
  }) async {
    if (bytes.isEmpty) throw 'That image could not be read.';
    if (_sampleRepo != null) {
      await _sampleRepo.uploadProfilePhoto(bytes, filename: filename);
      return;
    }
    await _call('uploadProfilePhoto', {
      'imageData': base64Encode(bytes),
      'filename': filename,
    });
  }

  @override
  Stream<WebAccountSettings> watchAccountSettings() =>
      _data.watchAccountSettings();

  @override
  Future<void> updatePrivacySettings({
    required bool isProfilePublic,
    required bool showOnlineStatus,
    required bool showEmail,
  }) => _data.updatePrivacySettings(
    isProfilePublic: isProfilePublic,
    showOnlineStatus: showOnlineStatus,
    showEmail: showEmail,
  );

  @override
  Future<void> updatePreferredTags(List<String> tags) =>
      _data.updatePreferredTags(tags);

  // ── Boards ──────────────────────────────────────────────────────────────

  @override
  Stream<List<Board>> watchMyBoards() => _data.watchMyBoards();

  @override
  Future<List<Board>> loadPublicBoards({int limit = 40}) =>
      _data.loadPublicBoards(limit: limit);

  @override
  Future<String> createBoard({
    required String name,
    String visibility = Board.visibilityPrivate,
    String privateJoinPolicy = Board.policyOwnerOnlyInvite,
    String whoCanInvite = Board.inviteOwnerOnly,
    String defaultLinkJoinRole = Board.roleViewer,
    List<String> tags = const [],
    bool allowMembersToCopy = false,
  }) => _data.createBoard(
    name: name,
    visibility: visibility,
    privateJoinPolicy: privateJoinPolicy,
    whoCanInvite: whoCanInvite,
    defaultLinkJoinRole: defaultLinkJoinRole,
    tags: tags,
    allowMembersToCopy: allowMembersToCopy,
  );

  @override
  Future<void> joinBoard(String boardIdOrCode) async {
    if (_sampleRepo != null) {
      await _sampleRepo.joinBoard(boardIdOrCode);
      return;
    }
    try {
      await _boardService!.joinBoard(boardIdOrCode);
    } on BoardJoinApprovalRequiredException catch (e) {
      throw e.toString();
    } on Exception catch (e) {
      throw _cleanExceptionMessage(e);
    }
  }

  @override
  Future<void> renameBoard(String boardId, String newName) =>
      _data.renameBoard(boardId, newName);

  @override
  Future<void> setBoardArchived(String boardId, {required bool archived}) =>
      _data.setBoardArchived(boardId, archived: archived);

  @override
  Future<void> setBoardPaused(String boardId, {required bool paused}) async {
    if (_sampleRepo != null) {
      await _sampleRepo.setBoardPaused(boardId, paused: paused);
      return;
    }
    await _boardService!.setBoardPaused(boardId, isPaused: paused);
  }

  @override
  Future<void> deleteBoard(String boardId) async {
    if (_sampleRepo != null) {
      await _sampleRepo.deleteBoard(boardId);
      return;
    }
    await _boardService!.deleteBoard(boardId);
  }

  @override
  Future<void> duplicateBoard(String boardId, {String? customTitle}) =>
      _data.duplicateBoard(boardId, customTitle: customTitle);

  @override
  Future<void> updateBoardTags(String boardId, List<String> tags) =>
      _data.updateBoardTags(boardId, tags);

  @override
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    bool? allowMembersToCopy,
  }) async {
    if (_sampleRepo != null) {
      await _sampleRepo.updateBoardSettings(
        boardId: boardId,
        visibility: visibility,
        privateJoinPolicy: privateJoinPolicy,
        whoCanInvite: whoCanInvite,
        defaultLinkJoinRole: defaultLinkJoinRole,
        allowMembersToCopy: allowMembersToCopy,
      );
      return;
    }
    await _boardService!.updateBoardSettings(
      boardId: boardId,
      visibility: normalizeVisibility(visibility),
      privateJoinPolicy: normalizePrivateJoinPolicy(privateJoinPolicy),
      whoCanInvite: normalizeWhoCanInvite(whoCanInvite),
      defaultLinkJoinRole: normalizeLinkJoinRole(defaultLinkJoinRole),
      allowMembersToCopy: allowMembersToCopy,
    );
  }

  // ── Workspaces ──────────────────────────────────────────────────────────

  @override
  Stream<List<Workspace>> watchMyWorkspaces() => _data.watchMyWorkspaces();

  @override
  Stream<List<Board>> watchWorkspaceBoards(String workspaceId) =>
      _data.watchWorkspaceBoards(workspaceId);

  @override
  Future<String> createWorkspace({
    required String name,
    required String description,
  }) async {
    if (_sampleRepo != null) {
      return _sampleRepo.createWorkspace(name: name, description: description);
    }
    final data = await _callData('createWorkspace', {
      'name': name.trim(),
      'description': description.trim(),
    });
    final id = data['workspaceId'];
    if (id is! String || id.isEmpty) {
      throw 'The workspace could not be created. Please try again.';
    }
    return id;
  }

  @override
  Future<void> updateWorkspace({
    required String workspaceId,
    String? name,
    String? description,
  }) {
    if (_sampleRepo != null) {
      return _sampleRepo.updateWorkspace(
        workspaceId: workspaceId,
        name: name,
        description: description,
      );
    }
    return _call('updateWorkspace', {
      'workspaceId': workspaceId,
      if (name != null) 'name': name.trim(),
      if (description != null) 'description': description.trim(),
    });
  }

  @override
  Future<void> addBoardToWorkspace({
    required String workspaceId,
    required String boardId,
  }) {
    if (_sampleRepo != null) {
      return _sampleRepo.addBoardToWorkspace(
        workspaceId: workspaceId,
        boardId: boardId,
      );
    }
    return _call('addBoardToWorkspace', {
      'workspaceId': workspaceId,
      'boardId': boardId,
    });
  }

  @override
  Future<void> removeBoardFromWorkspace({
    required String workspaceId,
    required String boardId,
  }) {
    if (_sampleRepo != null) {
      return _sampleRepo.removeBoardFromWorkspace(
        workspaceId: workspaceId,
        boardId: boardId,
      );
    }
    return _call('removeBoardFromWorkspace', {
      'workspaceId': workspaceId,
      'boardId': boardId,
    });
  }

  @override
  Stream<List<WorkspaceMember>> watchWorkspaceMembers(String workspaceId) =>
      _data.watchWorkspaceMembers(workspaceId);

  @override
  Future<void> updateWorkspaceMemberRole({
    required String workspaceId,
    required String memberUid,
    required String role,
  }) => _data.updateWorkspaceMemberRole(
    workspaceId: workspaceId,
    memberUid: memberUid,
    role: role,
  );

  @override
  Future<void> removeWorkspaceMember({
    required String workspaceId,
    required String memberUid,
  }) => _data.removeWorkspaceMember(
    workspaceId: workspaceId,
    memberUid: memberUid,
  );

  @override
  Future<void> inviteToWorkspace({
    required String workspaceId,
    required List<String> userIds,
  }) async {
    final ids = [
      for (final id in userIds)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    if (ids.isEmpty) throw 'Choose someone to invite.';
    if (_sampleRepo != null) {
      await _sampleRepo.inviteToWorkspace(
        workspaceId: workspaceId,
        userIds: ids,
      );
      return;
    }
    await _callData('inviteToWorkspace', {
      'workspaceId': workspaceId,
      'invitedUserIds': ids,
    });
  }

  @override
  Future<void> leaveWorkspace(String workspaceId) {
    if (_sampleRepo != null) {
      return _sampleRepo.leaveWorkspace(workspaceId);
    }
    return _call('leaveWorkspace', {
      'workspaceId': workspaceId,
      'importedBoardsToKeep': const <String>[],
    });
  }

  @override
  Future<void> deleteWorkspace(String workspaceId) {
    if (_sampleRepo != null) {
      return _sampleRepo.deleteWorkspace(workspaceId);
    }
    return _call('deleteWorkspace', {'workspaceId': workspaceId});
  }

  // ── Invites ─────────────────────────────────────────────────────────────

  @override
  Stream<List<BoardInvitation>> watchBoardInvites() =>
      _data.watchBoardInvites();

  @override
  Stream<List<WorkspaceInvite>> watchWorkspaceInvites() =>
      _data.watchWorkspaceInvites();

  @override
  Future<void> acceptBoardInvite(String inviteId) => _sampleRepo != null
      ? _sampleRepo.acceptBoardInvite(inviteId)
      : _call('acceptBoardInvite', {'inviteId': inviteId});

  @override
  Future<void> declineBoardInvite(String inviteId) => _sampleRepo != null
      ? _sampleRepo.declineBoardInvite(inviteId)
      : _call('declineBoardInvite', {'inviteId': inviteId});

  @override
  Future<void> acceptWorkspaceInvite(String inviteId) => _sampleRepo != null
      ? _sampleRepo.acceptWorkspaceInvite(inviteId)
      : _call('acceptWorkspaceInvite', {'inviteId': inviteId});

  @override
  Future<void> declineWorkspaceInvite(String inviteId) => _sampleRepo != null
      ? _sampleRepo.declineWorkspaceInvite(inviteId)
      : _call('rejectWorkspaceInvite', {'inviteId': inviteId});

  // ── Friends ─────────────────────────────────────────────────────────────

  @override
  Stream<List<FriendRequest>> watchIncomingFriendRequests() =>
      _data.watchIncomingFriendRequests();

  @override
  Stream<List<Friend>> watchFriends() => _data.watchFriends();

  @override
  Future<void> acceptFriendRequest(String requestId) => _sampleRepo != null
      ? _sampleRepo.acceptFriendRequest(requestId)
      : _call('acceptFriendRequest', {'requestId': requestId});

  @override
  Future<void> declineFriendRequest(String requestId) => _sampleRepo != null
      ? _sampleRepo.declineFriendRequest(requestId)
      : _call('declineFriendRequest', {'requestId': requestId});

  @override
  Future<List<Friend>> searchUsersByEmail(String email) =>
      _data.searchUsersByEmail(email);

  @override
  Future<void> sendFriendRequest(String targetUid) => _sampleRepo != null
      ? _sampleRepo.sendFriendRequest(targetUid)
      : _call('sendFriendRequest', {'targetUid': targetUid});

  @override
  Future<void> unfriend(String targetUid) => _sampleRepo != null
      ? _sampleRepo.unfriend(targetUid)
      : _call('unfriendUser', {'targetUid': targetUid});

  @override
  Stream<List<Friend>> watchBlockedUsers() => _data.watchBlockedUsers();

  @override
  Future<void> blockUser(String targetUid) => _sampleRepo != null
      ? _sampleRepo.blockUser(targetUid)
      : _call('blockUser', {'targetUid': targetUid});

  @override
  Future<void> unblockUser(String targetUid) => _sampleRepo != null
      ? _sampleRepo.unblockUser(targetUid)
      : _call('unblockUser', {'targetUid': targetUid});

  // ── Notifications ───────────────────────────────────────────────────────

  @override
  Stream<List<InAppNotification>> watchNotifications() =>
      _data.watchNotifications();

  @override
  Future<void> deleteNotification(String notificationId) =>
      _data.deleteNotification(notificationId);

  @override
  Stream<Set<String>> watchReadNotificationIds() =>
      _data.watchReadNotificationIds();

  @override
  Future<void> markNotificationRead(String id) =>
      _data.markNotificationRead(id);

  @override
  Future<void> markAllNotificationsRead(Iterable<String> ids) =>
      _data.markAllNotificationsRead(ids);

  @override
  Stream<List<InAppNotification>> watchNotificationsWithReadState() =>
      _data.watchNotificationsWithReadState();

  // ── Cloud Function helpers ──────────────────────────────────────────────

  Future<void> _call(String name, Map<String, dynamic> data) async {
    await _callData(name, data);
  }

  Future<Map<String, dynamic>> _callData(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions!.httpsCallable(name).call(data);
      final body = result.data;
      if (body is Map && body['success'] == false) {
        throw (body['message'] as String?) ??
            'That did not work. Please try again.';
      }
      return body is Map ? Map<String, dynamic>.from(body) : const {};
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'That did not work. Please try again.';
    }
  }

  static String _cleanExceptionMessage(Exception e) {
    final text = e.toString().trim();
    const prefix = 'Exception: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
  }
}
