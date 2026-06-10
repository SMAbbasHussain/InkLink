import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/services/friends/friends_service.dart';
import 'friends_event.dart';
import 'friends_state.dart';

export 'friends_event.dart';
export 'friends_state.dart';

class _FriendsStreamFailed extends FriendsEvent {
  final String error;

  _FriendsStreamFailed(this.error);
}

class _BlockedUsersUpdated extends FriendsEvent {
  final List<Map<String, dynamic>> blockedUsers;
  _BlockedUsersUpdated(this.blockedUsers);
}

class FriendsBloc extends Bloc<FriendsEvent, FriendsState> {
  final FriendsService friendsService;
  StreamSubscription? _friendsSubscription;
  StreamSubscription? _blockedUsersSubscription;
  Set<String> _pendingOutgoingTargetUids = <String>{};
  Set<String> _sendingRequestTargetUids = <String>{};
  Set<String> _acceptingRequestIds = <String>{};
  Set<String> _decliningRequestIds = <String>{};
  Set<String> _cancelingRequestIds = <String>{};
  bool _isOffline = false;

  FriendsBloc({required this.friendsService}) : super(FriendsInitial()) {
    on<_FriendsStreamFailed>((event, emit) {
      final message = event.error.toLowerCase();
      if (message.contains('permission-denied') ||
          message.contains('permission denied')) {
        emit(FriendsInitial());
        return;
      }
      emit(FriendsError(event.error));
    });
    on<LoadFriendsInfo>((event, emit) async {
      emit(FriendsLoading());

      // Cancel old subscription
      await _friendsSubscription?.cancel();
      _friendsSubscription = null;
      add(FriendsConnectivityUpdated(false));
      _refreshConnectivity();

      // Start fresh listeners
      _friendsSubscription = friendsService.watchFriendsInfo().listen(
        (info) {
          if (_isOffline) {
            add(FriendsConnectivityUpdated(false));
          }
          add(
            UpdateFriendsLists(
              friends: info.friends,
              incomingRequests: info.incomingRequests,
              outgoingRequests: info.outgoingRequests,
            ),
          );
        },
        onError: (error) {
          if (isClosed) return;
          add(_FriendsStreamFailed(error.toString()));
        },
      );
    });

    on<StopFriendsInfo>((event, emit) async {
      await _friendsSubscription?.cancel();
      _friendsSubscription = null;
      _pendingOutgoingTargetUids = <String>{};
      _sendingRequestTargetUids = <String>{};
      _acceptingRequestIds = <String>{};
      _decliningRequestIds = <String>{};
      _cancelingRequestIds = <String>{};
      _isOffline = false;
      emit(FriendsInitial());
    });

    on<UpdateFriendsLists>((event, emit) {
      _pendingOutgoingTargetUids = event.outgoingRequests
          .map((request) => request['toUid']?.toString() ?? '')
          .where((uid) => uid.isNotEmpty)
          .toSet();

      final blockedUsers = state is FriendsLoaded
          ? (state as FriendsLoaded).blockedUsers
          : const <Map<String, dynamic>>[];
      emit(
        FriendsLoaded(
          friends: event.friends,
          incomingRequests: event.incomingRequests,
          outgoingRequests: event.outgoingRequests,
          sendingRequestTargetUids: _sendingRequestTargetUids,
          acceptingRequestIds: _acceptingRequestIds,
          decliningRequestIds: _decliningRequestIds,
          cancelingRequestIds: _cancelingRequestIds,
          isOffline: _isOffline,
          blockedUsers: blockedUsers,
        ),
      );
    });

    on<LoadBlockedUsers>((event, emit) async {
      await _blockedUsersSubscription?.cancel();
      _blockedUsersSubscription = friendsService.watchBlockedUsers().listen(
        (blocked) {
          if (!isClosed) add(_BlockedUsersUpdated(blocked));
        },
        onError: (e) {
          if (!isClosed) add(_BlockedUsersUpdated([]));
        },
      );
    });

    on<_BlockedUsersUpdated>((event, emit) {
      if (state is FriendsLoaded) {
        emit((state as FriendsLoaded).copyWith(
          blockedUsers: event.blockedUsers,
        ));
      }
    });

    on<UnblockUserRequested>((event, emit) async {
      try {
        await friendsService.unblockUser(event.targetUid);
      } catch (_) {}
      add(LoadBlockedUsers());
    });

    on<FriendsConnectivityUpdated>((event, emit) {
      _isOffline = event.isOffline;

      final current = state;
      if (current is FriendsLoaded) {
        emit(current.copyWith(isOffline: _isOffline));
      } else if (current is EmailSearchResultsLoaded) {
        emit(
          EmailSearchResultsLoaded(
            result: current.result,
            friendUids: current.friendUids,
            pendingOutgoingUids: current.pendingOutgoingUids,
            sendingRequestTargetUids: _sendingRequestTargetUids,
            isOffline: _isOffline,
          ),
        );
      }
    });

    on<SearchUserByEmailRequested>((event, emit) async {
      emit(EmailSearchInProgress());
      try {
        final results = await friendsService.searchUsersByEmail(event.email);
        if (_isOffline) {
          add(FriendsConnectivityUpdated(false));
        }

        if (results.isEmpty) {
          emit(EmailSearchEmpty());
          return;
        }

        // Extract friend UIDs from current FriendsLoaded state if available
        final friendUids = <String>{};
        if (state is FriendsLoaded) {
          final friends = (state as FriendsLoaded).friends;
          friendUids.addAll(
            friends
                .map((f) => f['uid']?.toString() ?? '')
                .where((uid) => uid.isNotEmpty),
          );
        }

        emit(
          EmailSearchResultsLoaded(
            result: results.first,
            friendUids: friendUids,
            pendingOutgoingUids: _pendingOutgoingTargetUids,
            sendingRequestTargetUids: _sendingRequestTargetUids,
            isOffline: _isOffline,
          ),
        );
      } catch (e) {
        if (_looksOffline(e)) {
          add(FriendsConnectivityUpdated(true));
          emit(FriendsError('You are offline. Reconnect to search users.'));
          return;
        }
        emit(FriendsError("User not found"));
      }
    });

    on<AcceptFriendRequestRequested>((event, emit) async {
      if (event.requestId.isEmpty ||
          _acceptingRequestIds.contains(event.requestId)) {
        return;
      }
      _acceptingRequestIds = Set<String>.from(_acceptingRequestIds)
        ..add(event.requestId);
      final before = state;
      if (before is FriendsLoaded) {
        emit(before.copyWith(acceptingRequestIds: _acceptingRequestIds));
      }

      // Capture current state to restore it if needed
      final currentState = state;

      try {
        await friendsService.acceptFriendRequest(
          event.requestId,
          event.senderUid,
        );
        if (_isOffline) {
          add(FriendsConnectivityUpdated(false));
        }
        // Success! The stream from Firestore will automatically update the list.
      } catch (e) {
        if (_looksOffline(e)) {
          add(FriendsConnectivityUpdated(true));
        }
        // Restore previous state so the list doesn't vanish
        if (currentState is FriendsLoaded) {
          emit(currentState.copyWith(isOffline: _isOffline));
        }
        emit(FriendsError("Failed to accept: ${e.toString()}"));
      } finally {
        _acceptingRequestIds = Set<String>.from(_acceptingRequestIds)
          ..remove(event.requestId);
        final current = state;
        if (current is FriendsLoaded) {
          emit(current.copyWith(acceptingRequestIds: _acceptingRequestIds));
        }
      }
    });

    on<DeclineFriendRequestRequested>((event, emit) async {
      if (event.requestId.isEmpty ||
          _decliningRequestIds.contains(event.requestId)) {
        return;
      }
      _decliningRequestIds = Set<String>.from(_decliningRequestIds)
        ..add(event.requestId);
      final before = state;
      if (before is FriendsLoaded) {
        emit(before.copyWith(decliningRequestIds: _decliningRequestIds));
      }

      try {
        await friendsService.declineFriendRequest(event.requestId);
        if (_isOffline) {
          add(FriendsConnectivityUpdated(false));
        }
      } catch (e) {
        if (_looksOffline(e)) {
          add(FriendsConnectivityUpdated(true));
        }
        emit(FriendsError("Request declined"));
      } finally {
        _decliningRequestIds = Set<String>.from(_decliningRequestIds)
          ..remove(event.requestId);
        final current = state;
        if (current is FriendsLoaded) {
          emit(current.copyWith(decliningRequestIds: _decliningRequestIds));
        }
      }
    });

    on<CancelFriendRequestRequested>((event, emit) async {
      if (event.requestId.isEmpty ||
          _cancelingRequestIds.contains(event.requestId)) {
        return;
      }
      _cancelingRequestIds = Set<String>.from(_cancelingRequestIds)
        ..add(event.requestId);
      final before = state;
      if (before is FriendsLoaded) {
        emit(before.copyWith(cancelingRequestIds: _cancelingRequestIds));
      }

      try {
        await friendsService.cancelFriendRequest(
          event.requestId,
          event.targetUid,
        );
        if (_isOffline) {
          add(FriendsConnectivityUpdated(false));
        }
      } catch (e) {
        if (_looksOffline(e)) {
          add(FriendsConnectivityUpdated(true));
        }
        emit(FriendsError("Failed to cancel request"));
      } finally {
        _cancelingRequestIds = Set<String>.from(_cancelingRequestIds)
          ..remove(event.requestId);
        final current = state;
        if (current is FriendsLoaded) {
          emit(current.copyWith(cancelingRequestIds: _cancelingRequestIds));
        }
      }
    });

    on<SendFriendRequestRequested>((event, emit) async {
      if (event.targetUid.isEmpty ||
          _sendingRequestTargetUids.contains(event.targetUid)) {
        return;
      }
      _sendingRequestTargetUids = Set<String>.from(_sendingRequestTargetUids)
        ..add(event.targetUid);
      final before = state;
      if (before is FriendsLoaded) {
        emit(
          before.copyWith(sendingRequestTargetUids: _sendingRequestTargetUids),
        );
      }
      if (before is EmailSearchResultsLoaded) {
        emit(
          EmailSearchResultsLoaded(
            result: before.result,
            friendUids: before.friendUids,
            pendingOutgoingUids: before.pendingOutgoingUids,
            sendingRequestTargetUids: _sendingRequestTargetUids,
            isOffline: before.isOffline,
          ),
        );
      }

      try {
        await friendsService.sendFriendRequest(event.targetUid);
        if (_isOffline) {
          add(FriendsConnectivityUpdated(false));
        }
      } catch (e) {
        if (_looksOffline(e)) {
          add(FriendsConnectivityUpdated(true));
        }
        emit(FriendsError(e.toString()));
      } finally {
        _sendingRequestTargetUids = Set<String>.from(_sendingRequestTargetUids)
          ..remove(event.targetUid);
        final current = state;
        if (current is FriendsLoaded) {
          emit(
            current.copyWith(
              sendingRequestTargetUids: _sendingRequestTargetUids,
            ),
          );
        }
        if (current is EmailSearchResultsLoaded) {
          emit(
            EmailSearchResultsLoaded(
              result: current.result,
              friendUids: current.friendUids,
              pendingOutgoingUids: current.pendingOutgoingUids,
              sendingRequestTargetUids: _sendingRequestTargetUids,
              isOffline: current.isOffline,
            ),
          );
        }
      }
    });
  }

  Future<void> _refreshConnectivity() async {
    final isOnline = await friendsService.isOnline();
    add(FriendsConnectivityUpdated(!isOnline));
  }

  bool _looksOffline(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('offline') || message.contains('connection error');
  }

  Future<void> sendFriendRequestToUser(String targetUid) {
    return friendsService.sendFriendRequest(targetUid);
  }

  Future<void> stopForLogout() async {
    await _friendsSubscription?.cancel();
    _friendsSubscription = null;
    await _blockedUsersSubscription?.cancel();
    _blockedUsersSubscription = null;
    _pendingOutgoingTargetUids = <String>{};
    _sendingRequestTargetUids = <String>{};
    _acceptingRequestIds = <String>{};
    _decliningRequestIds = <String>{};
    _cancelingRequestIds = <String>{};
    _isOffline = false;
  }

  Future<void> unfriendUser(String targetUid) {
    return friendsService.unfriendUser(targetUid);
  }

  Future<void> blockUser(String targetUid, {String? reason}) {
    return friendsService.blockUser(targetUid, reason: reason);
  }

  Future<void> reportUser(String targetUid, {String? reason}) {
    return friendsService.reportUser(targetUid, reason: reason);
  }

  Future<void> unblockUser(String targetUid) {
    return friendsService.unblockUser(targetUid);
  }

  Stream<List<Map<String, dynamic>>> watchBlockedUsers() {
    return friendsService.watchBlockedUsers();
  }

  @override
  Future<void> close() async {
    await stopForLogout();
    return super.close();
  }
}
