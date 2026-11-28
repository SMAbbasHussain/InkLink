import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/models/friends/friend.dart';
import '../../../../domain/models/friends/friend_request.dart';
import '../../../domain/services/web_companion_service.dart';

class WebFriendsState {
  final List<FriendRequest> friendRequests;
  final bool friendRequestsLoading;
  final Object? friendRequestsError;

  final List<Friend> friends;
  final bool friendsLoading;
  final Object? friendsError;

  final List<Friend> blockedUsers;
  final bool blockedUsersLoading;
  final Object? blockedUsersError;

  const WebFriendsState({
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

  WebFriendsState copyWith({
    List<FriendRequest>? friendRequests,
    bool? friendRequestsLoading,
    Object? Function()? friendRequestsError,
    List<Friend>? friends,
    bool? friendsLoading,
    Object? Function()? friendsError,
    List<Friend>? blockedUsers,
    bool? blockedUsersLoading,
    Object? Function()? blockedUsersError,
  }) => WebFriendsState(
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

/// Manages incoming friend requests, friends list, and blocked users for the
/// web companion via [WebCompanionService].
class WebFriendsCubit extends Cubit<WebFriendsState> {
  final WebCompanionService _service;
  final List<StreamSubscription<dynamic>> _subs = [];

  WebFriendsCubit({required this._service}) : super(const WebFriendsState()) {
    rebind();
  }

  void rebind() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    emit(const WebFriendsState());
    _subs.addAll([
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
