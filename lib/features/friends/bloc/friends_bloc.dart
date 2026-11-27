import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/app_error_formatter.dart';
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

/// An incoming friend request hidden from the list while its accept/decline
/// call is on the wire. Keeping the original request and its position lets a
/// failed decision put the tile back exactly where it was.
class _OptimisticFriendRequest {
  final Map<String, dynamic> request;
  final int index;

  const _OptimisticFriendRequest(this.request, this.index);
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
  final Map<String, _OptimisticFriendRequest> _optimisticIncomingRemovals =
      <String, _OptimisticFriendRequest>{};
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
      _optimisticIncomingRemovals.clear();
      _isOffline = false;
      emit(FriendsInitial());
    });

    on<UpdateFriendsLists>((event, emit) {
      final currentUid = friendsService.currentUserId?.trim();
      final sanitizedFriends = event.friends.where((f) {
        final fUid = (f['uid'] ?? '').toString().trim();
        if (currentUid != null && fUid.isNotEmpty && fUid == currentUid) return false;
        final status = f['friendshipStatus']?.toString().toLowerCase();
        if (status == 'friendshipstatus.self' || status == 'self') return false;
        return true;
      }).toList();

      _pendingOutgoingTargetUids = event.outgoingRequests
          .map((request) => request['toUid']?.toString() ?? '')
          .where((uid) => uid.isNotEmpty)
          .toSet();

      final current = state;
      if (current is EmailSearchResultsLoaded) {
        final friendUids = sanitizedFriends
            .map((f) => f['uid']?.toString() ?? '')
            .where((uid) => uid.isNotEmpty)
            .toSet();
        emit(
          EmailSearchResultsLoaded(
            result: current.result,
            friendUids: friendUids,
            pendingOutgoingUids: _pendingOutgoingTargetUids,
            sendingRequestTargetUids: _sendingRequestTargetUids,
            isOffline: _isOffline,
          ),
        );
        return;
      }

      if (current is EmailSearchInProgress || current is EmailSearchEmpty) {
        return;
      }

      final blockedUsers = state is FriendsLoaded
          ? (state as FriendsLoaded).blockedUsers
          : const <Map<String, dynamic>>[];
      emit(
        FriendsLoaded(
          friends: sanitizedFriends,
          incomingRequests: _visibleIncomingRequests(event.incomingRequests),
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
          _optimisticIncomingRemovals.containsKey(event.requestId)) {
        return;
      }
      // Resolve the tile immediately: the spinner is only for handing the
      // decision to the function, not for the owner's answer.
      _hideIncomingRequest(event.requestId, emit);
      event.onCompleted?.call(true, null);

      try {
        await friendsService.acceptFriendRequest(
          event.requestId,
          event.senderUid,
        );
        _optimisticIncomingRemovals.remove(event.requestId);
        if (_isOffline) {
          add(FriendsConnectivityUpdated(false));
        }
      } catch (e) {
        if (_looksOffline(e)) {
          add(FriendsConnectivityUpdated(true));
        }
        final message = AppErrorFormatter.cleanMessage(e);
        // Nothing changed on the server: put the request back and tell the
        // member now that the earlier success was only optimistic.
        _restoreIncomingRequest(event.requestId, emit);
        event.onCompleted?.call(false, message);
      }
    });

    on<DeclineFriendRequestRequested>((event, emit) async {
      if (event.requestId.isEmpty ||
          _optimisticIncomingRemovals.containsKey(event.requestId)) {
        return;
      }
      _hideIncomingRequest(event.requestId, emit);
      event.onCompleted?.call(true, null);

      try {
        await friendsService.declineFriendRequest(event.requestId);
        _optimisticIncomingRemovals.remove(event.requestId);
        if (_isOffline) {
          add(FriendsConnectivityUpdated(false));
        }
      } catch (e) {
        if (_looksOffline(e)) {
          add(FriendsConnectivityUpdated(true));
        }
        final message = AppErrorFormatter.cleanMessage(e);
        _restoreIncomingRequest(event.requestId, emit);
        event.onCompleted?.call(false, message);
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
      _pendingOutgoingTargetUids = Set<String>.from(_pendingOutgoingTargetUids)
        ..add(event.targetUid);

      final before = state;
      if (before is FriendsLoaded) {
        final updatedOutgoing = List<Map<String, dynamic>>.from(before.outgoingRequests);
        if (!updatedOutgoing.any((r) => r['toUid'] == event.targetUid)) {
          updatedOutgoing.add({
            'requestId': '${friendsService.currentUserId ?? ''}_${event.targetUid}',
            'id': '${friendsService.currentUserId ?? ''}_${event.targetUid}',
            'fromUid': friendsService.currentUserId ?? '',
            'toUid': event.targetUid,
            'status': 'pending',
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
        emit(
          before.copyWith(
            outgoingRequests: updatedOutgoing,
            sendingRequestTargetUids: _sendingRequestTargetUids,
          ),
        );
      }
      if (before is EmailSearchResultsLoaded) {
        emit(
          EmailSearchResultsLoaded(
            result: before.result,
            friendUids: before.friendUids,
            pendingOutgoingUids: _pendingOutgoingTargetUids,
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
        emit(FriendsError(AppErrorFormatter.cleanMessage(e)));
      } finally {
        _sendingRequestTargetUids = Set<String>.from(_sendingRequestTargetUids)
          ..remove(event.targetUid);
        final current = state;
        if (current is FriendsLoaded) {
          final updatedOutgoing = List<Map<String, dynamic>>.from(current.outgoingRequests);
          if (!updatedOutgoing.any((r) => r['toUid'] == event.targetUid)) {
            updatedOutgoing.add({
              'requestId': '${friendsService.currentUserId ?? ''}_${event.targetUid}',
              'id': '${friendsService.currentUserId ?? ''}_${event.targetUid}',
              'fromUid': friendsService.currentUserId ?? '',
              'toUid': event.targetUid,
              'status': 'pending',
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
          emit(
            current.copyWith(
              outgoingRequests: updatedOutgoing,
              sendingRequestTargetUids: _sendingRequestTargetUids,
            ),
          );
        }
        if (current is EmailSearchResultsLoaded) {
          emit(
            EmailSearchResultsLoaded(
              result: current.result,
              friendUids: current.friendUids,
              pendingOutgoingUids: _pendingOutgoingTargetUids,
              sendingRequestTargetUids: _sendingRequestTargetUids,
              isOffline: current.isOffline,
            ),
          );
        }
      }
    });
  }

  String _incomingRequestId(Map<String, dynamic> request) =>
      (request['id'] ?? request['requestId'] ?? '').toString();

  /// Incoming requests with optimistic decisions removed. Firestore snapshot
  /// updates are filtered through this so a tile cannot flash back while the
  /// Cloud Function is still running.
  List<Map<String, dynamic>> _visibleIncomingRequests(
    List<Map<String, dynamic>> requests,
  ) {
    return requests
        .where(
          (request) => !_optimisticIncomingRemovals.containsKey(
            _incomingRequestId(request),
          ),
        )
        .toList(growable: false);
  }

  /// Drops the request from the visible list right away and remembers it so a
  /// failed decision can restore it at its original position.
  void _hideIncomingRequest(
    String requestId,
    Emitter<FriendsState> emit,
  ) {
    final current = state;
    if (current is! FriendsLoaded) return;
    final index = current.incomingRequests.indexWhere(
      (request) => _incomingRequestId(request) == requestId,
    );
    _optimisticIncomingRemovals[requestId] = _OptimisticFriendRequest(
      index >= 0
          ? current.incomingRequests[index]
          : <String, dynamic>{'id': requestId},
      index < 0 ? 0 : index,
    );
    emit(
      current.copyWith(
        incomingRequests: current.incomingRequests
            .where((request) => _incomingRequestId(request) != requestId)
            .toList(growable: false),
        acceptingRequestIds: const <String>{},
        decliningRequestIds: const <String>{},
      ),
    );
  }

  void _restoreIncomingRequest(String requestId, Emitter<FriendsState> emit) {
    final removal = _optimisticIncomingRemovals.remove(requestId);
    if (removal == null) return;
    final current = state;
    if (current is! FriendsLoaded) return;
    if (current.incomingRequests.any(
      (request) => _incomingRequestId(request) == requestId,
    )) {
      return;
    }
    final requests = List<Map<String, dynamic>>.from(current.incomingRequests);
    requests.insert(
      removal.index.clamp(0, requests.length),
      removal.request,
    );
    emit(current.copyWith(incomingRequests: requests, isOffline: _isOffline));
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
    _optimisticIncomingRemovals.clear();
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
