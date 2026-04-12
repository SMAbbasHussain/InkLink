import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/services/friends/friends_service.dart';
import 'friends_event.dart';
import 'friends_state.dart';

class FriendsBloc extends Bloc<FriendsEvent, FriendsState> {
  final FriendsService friendsService;
  StreamSubscription? _friendsSubscription;
  Set<String> _pendingOutgoingTargetUids = <String>{};
  bool _isOffline = false;

  FriendsBloc({required this.friendsService}) : super(FriendsInitial()) {
    on<LoadFriendsInfo>((event, emit) async {
      emit(FriendsLoading());
      await _friendsSubscription?.cancel();
      add(FriendsConnectivityUpdated(false));
      _refreshConnectivity();

      // In a full implementation, you'd combine streams.
      // For now, let's fix the syntax error.
      _friendsSubscription = friendsService.watchFriendsInfo().listen((info) {
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
      });
    });

    on<UpdateFriendsLists>((event, emit) {
      _pendingOutgoingTargetUids = event.outgoingRequests
          .map((request) => request['toUid']?.toString() ?? '')
          .where((uid) => uid.isNotEmpty)
          .toSet();

      emit(
        FriendsLoaded(
          friends: event.friends,
          incomingRequests: event.incomingRequests,
          outgoingRequests: event.outgoingRequests,
          isOffline: _isOffline,
        ),
      );
    });

    on<FriendsConnectivityUpdated>((event, emit) {
      _isOffline = event.isOffline;

      final current = state;
      if (current is FriendsLoaded) {
        emit(
          FriendsLoaded(
            friends: current.friends,
            incomingRequests: current.incomingRequests,
            outgoingRequests: current.outgoingRequests,
            isOffline: _isOffline,
          ),
        );
      } else if (current is EmailSearchResultsLoaded) {
        emit(
          EmailSearchResultsLoaded(
            result: current.result,
            friendUids: current.friendUids,
            pendingOutgoingUids: current.pendingOutgoingUids,
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
          emit(
            FriendsLoaded(
              friends: currentState.friends,
              incomingRequests: currentState.incomingRequests,
              outgoingRequests: currentState.outgoingRequests,
              isOffline: _isOffline,
            ),
          );
        }
        emit(FriendsError("Failed to accept: ${e.toString()}"));
      }
    });

    on<DeclineFriendRequestRequested>((event, emit) async {
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
      }
    });

    on<SendFriendRequestRequested>((event, emit) async {
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
  Future<void> close() {
    _friendsSubscription?.cancel();
    return super.close();
  }
}
