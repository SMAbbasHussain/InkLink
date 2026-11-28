import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/friends/friend.dart';
import '../../domain/models/friends/friend_request.dart';
import '../../domain/models/invitation/board_invitation.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/workspace.dart';
import '../domain/web_companion_service.dart';

class WebSocialState {
  final UserModel? profile;
  final bool profileLoading;
  final Object? profileError;

  final List<BoardInvitation> boardInvites;
  final bool boardInvitesLoading;
  final Object? boardInvitesError;

  final List<WorkspaceInvite> workspaceInvites;
  final bool workspaceInvitesLoading;
  final Object? workspaceInvitesError;

  final List<FriendRequest> friendRequests;
  final bool friendRequestsLoading;
  final Object? friendRequestsError;

  final List<Friend> friends;
  final bool friendsLoading;
  final Object? friendsError;

  final List<Friend> blockedUsers;
  final bool blockedUsersLoading;
  final Object? blockedUsersError;

  const WebSocialState({
    this.profile,
    this.profileLoading = true,
    this.profileError,
    this.boardInvites = const [],
    this.boardInvitesLoading = true,
    this.boardInvitesError,
    this.workspaceInvites = const [],
    this.workspaceInvitesLoading = true,
    this.workspaceInvitesError,
    this.friendRequests = const [],
    this.friendRequestsLoading = true,
    this.friendRequestsError,
    this.friends = const [],
    this.friendsLoading = true,
    this.friendsError,
    this.blockedUsers = const [],
    this.blockedUsersLoading = true,
    this.blockedUsersError,
  });

  int get totalPendingInvites => boardInvites.length + workspaceInvites.length;

  WebSocialState copyWith({
    UserModel? Function()? profile,
    bool? profileLoading,
    Object? Function()? profileError,
    List<BoardInvitation>? boardInvites,
    bool? boardInvitesLoading,
    Object? Function()? boardInvitesError,
    List<WorkspaceInvite>? workspaceInvites,
    bool? workspaceInvitesLoading,
    Object? Function()? workspaceInvitesError,
    List<FriendRequest>? friendRequests,
    bool? friendRequestsLoading,
    Object? Function()? friendRequestsError,
    List<Friend>? friends,
    bool? friendsLoading,
    Object? Function()? friendsError,
    List<Friend>? blockedUsers,
    bool? blockedUsersLoading,
    Object? Function()? blockedUsersError,
  }) => WebSocialState(
    profile: profile != null ? profile() : this.profile,
    profileLoading: profileLoading ?? this.profileLoading,
    profileError: profileError != null ? profileError() : this.profileError,
    boardInvites: boardInvites ?? this.boardInvites,
    boardInvitesLoading: boardInvitesLoading ?? this.boardInvitesLoading,
    boardInvitesError: boardInvitesError != null
        ? boardInvitesError()
        : this.boardInvitesError,
    workspaceInvites: workspaceInvites ?? this.workspaceInvites,
    workspaceInvitesLoading:
        workspaceInvitesLoading ?? this.workspaceInvitesLoading,
    workspaceInvitesError: workspaceInvitesError != null
        ? workspaceInvitesError()
        : this.workspaceInvitesError,
    friendRequests: friendRequests ?? this.friendRequests,
    friendRequestsLoading: friendRequestsLoading ?? this.friendRequestsLoading,
    friendRequestsError: friendRequestsError != null
        ? friendRequestsError()
        : this.friendRequestsError,
    friends: friends ?? this.friends,
    friendsLoading: friendsLoading ?? this.friendsLoading,
    friendsError: friendsError != null ? friendsError() : this.friendsError,
    blockedUsers: blockedUsers ?? this.blockedUsers,
    blockedUsersLoading: blockedUsersLoading ?? this.blockedUsersLoading,
    blockedUsersError: blockedUsersError != null
        ? blockedUsersError()
        : this.blockedUsersError,
  );
}

/// Manages profile, invites, friends, and blocked users state for the web
/// companion via [WebCompanionService].
class WebSocialCubit extends Cubit<WebSocialState> {
  final WebCompanionService _service;
  final List<StreamSubscription<dynamic>> _subs = [];

  WebSocialCubit({required this._service}) : super(const WebSocialState()) {
    rebind();
  }

  void rebind() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    emit(const WebSocialState());
    _subs.addAll([
      _service.watchMyProfile().listen(
        (profile) {
          if (!isClosed) {
            emit(
              state.copyWith(
                profile: () => profile,
                profileLoading: false,
                profileError: () => null,
              ),
            );
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            emit(
              state.copyWith(profileLoading: false, profileError: () => error),
            );
          }
        },
      ),
      _service.watchBoardInvites().listen(
        (invites) {
          if (!isClosed) {
            emit(
              state.copyWith(
                boardInvites: invites,
                boardInvitesLoading: false,
                boardInvitesError: () => null,
              ),
            );
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            emit(
              state.copyWith(
                boardInvitesLoading: false,
                boardInvitesError: () => error,
              ),
            );
          }
        },
      ),
      _service.watchWorkspaceInvites().listen(
        (invites) {
          if (!isClosed) {
            emit(
              state.copyWith(
                workspaceInvites: invites,
                workspaceInvitesLoading: false,
                workspaceInvitesError: () => null,
              ),
            );
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            emit(
              state.copyWith(
                workspaceInvitesLoading: false,
                workspaceInvitesError: () => error,
              ),
            );
          }
        },
      ),
      _service.watchIncomingFriendRequests().listen(
        (requests) {
          if (!isClosed) {
            emit(
              state.copyWith(
                friendRequests: requests,
                friendRequestsLoading: false,
                friendRequestsError: () => null,
              ),
            );
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            emit(
              state.copyWith(
                friendRequestsLoading: false,
                friendRequestsError: () => error,
              ),
            );
          }
        },
      ),
      _service.watchFriends().listen(
        (friends) {
          if (!isClosed) {
            emit(
              state.copyWith(
                friends: friends,
                friendsLoading: false,
                friendsError: () => null,
              ),
            );
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            emit(
              state.copyWith(friendsLoading: false, friendsError: () => error),
            );
          }
        },
      ),
      _service.watchBlockedUsers().listen(
        (blocked) {
          if (!isClosed) {
            emit(
              state.copyWith(
                blockedUsers: blocked,
                blockedUsersLoading: false,
                blockedUsersError: () => null,
              ),
            );
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            emit(
              state.copyWith(
                blockedUsersLoading: false,
                blockedUsersError: () => error,
              ),
            );
          }
        },
      ),
    ]);
  }

  Future<void> updateProfile({required String name, required String bio}) =>
      _service.updateProfile(name: name, bio: bio);

  Future<void> uploadProfilePhoto(
    Uint8List bytes, {
    required String filename,
  }) => _service.uploadProfilePhoto(bytes, filename: filename);

  Future<void> acceptBoardInvite(String inviteId) =>
      _service.acceptBoardInvite(inviteId);

  Future<void> declineBoardInvite(String inviteId) =>
      _service.declineBoardInvite(inviteId);

  Future<void> acceptWorkspaceInvite(String inviteId) =>
      _service.acceptWorkspaceInvite(inviteId);

  Future<void> declineWorkspaceInvite(String inviteId) =>
      _service.declineWorkspaceInvite(inviteId);

  Future<void> acceptFriendRequest(String requestId) =>
      _service.acceptFriendRequest(requestId);

  Future<void> declineFriendRequest(String requestId) =>
      _service.declineFriendRequest(requestId);

  Future<List<Friend>> searchUsersByEmail(String email) =>
      _service.searchUsersByEmail(email);

  Future<void> sendFriendRequest(String targetUid) =>
      _service.sendFriendRequest(targetUid);

  Future<void> unfriend(String targetUid) => _service.unfriend(targetUid);

  Future<void> blockUser(String targetUid) => _service.blockUser(targetUid);

  Future<void> unblockUser(String targetUid) => _service.unblockUser(targetUid);

  @override
  Future<void> close() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    return super.close();
  }
}
