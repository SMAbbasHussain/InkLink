import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import '../../../domain/repositories/friends/friends_repository.dart';
import 'friends_event.dart';
import 'friends_state.dart';

class FriendsBloc extends Bloc<FriendsEvent, FriendsState> {
  final FriendsRepository friendsRepo;
  StreamSubscription? _friendsSubscription;

  FriendsBloc({required this.friendsRepo}) : super(FriendsInitial()) {
    on<LoadFriendsInfo>((event, emit) async {
      emit(FriendsLoading());
      await _friendsSubscription?.cancel();

      // In a full implementation, you'd combine streams.
      // For now, let's fix the syntax error.
      _friendsSubscription =
          Rx.combineLatest2(
            friendsRepo.watchFriendsList(),
            friendsRepo.watchIncomingRequests(),
            (
              List<Map<String, dynamic>> friends,
              List<Map<String, dynamic>> requests,
            ) {
              return UpdateFriendsLists(
                friends: friends,
                incomingRequests: requests,
              );
            },
          ).listen((updateEvent) {
            add(updateEvent);
          });
    });

    on<UpdateFriendsLists>((event, emit) {
      emit(
        FriendsLoaded(
          friends: event.friends,
          incomingRequests: event.incomingRequests,
        ),
      );
    });

    on<SearchUserByEmailRequested>((event, emit) async {
      emit(FriendsLoading());
      try {
        final results = await friendsRepo.searchUsersByEmail(event.email);
        emit(SearchResultsLoaded(results));
      } catch (e) {
        emit(FriendsError("User not found"));
      }
    });

    on<AcceptFriendRequestRequested>((event, emit) async {
      // Capture current state to restore it if needed
      final currentState = state;

      try {
        await friendsRepo.acceptFriendRequest(event.requestId, event.senderUid);
        // Success! The stream from Firestore will automatically update the list.
      } catch (e) {
        // Restore previous state so the list doesn't vanish
        if (currentState is FriendsLoaded) {
          emit(
            FriendsLoaded(
              friends: currentState.friends,
              incomingRequests: currentState.incomingRequests,
            ),
          );
        }
        emit(FriendsError("Failed to accept: ${e.toString()}"));
      }
    });

    on<DeclineFriendRequestRequested>((event, emit) async {
      try {
        await friendsRepo.declineFriendRequest(event.requestId);
      } catch (e) {
        emit(FriendsError("Request declined"));
      }
    });

    on<SendFriendRequestRequested>((event, emit) async {
      try {
        await friendsRepo.sendFriendRequest(event.targetUid);
      } catch (e) {
        emit(FriendsError(e.toString()));
      }
    });
  }

  @override
  Future<void> close() {
    _friendsSubscription?.cancel();
    return super.close();
  }
}
