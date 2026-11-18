abstract class FriendsEvent {}

class LoadFriendsInfo extends FriendsEvent {}

class StopFriendsInfo extends FriendsEvent {}

class SearchUserByEmailRequested extends FriendsEvent {
  final String email;
  SearchUserByEmailRequested(this.email);
}

class SendFriendRequestRequested extends FriendsEvent {
  final String targetUid;
  SendFriendRequestRequested(this.targetUid);
}

typedef FriendRequestDecisionCallback =
    void Function(bool success, String? error);

class AcceptFriendRequestRequested extends FriendsEvent {
  final String requestId;
  final String senderUid;
  final FriendRequestDecisionCallback? onCompleted;
  AcceptFriendRequestRequested(
    this.requestId,
    this.senderUid, {
    this.onCompleted,
  });
}

class DeclineFriendRequestRequested extends FriendsEvent {
  final String requestId;
  final FriendRequestDecisionCallback? onCompleted;
  DeclineFriendRequestRequested(this.requestId, {this.onCompleted});
}

class CancelFriendRequestRequested extends FriendsEvent {
  final String requestId;
  final String targetUid;
  CancelFriendRequestRequested(this.requestId, this.targetUid);
}

// FIX: Use named parameters here
class UpdateFriendsLists extends FriendsEvent {
  final List<Map<String, dynamic>> friends;
  final List<Map<String, dynamic>> incomingRequests;
  final List<Map<String, dynamic>> outgoingRequests;

  UpdateFriendsLists({
    required this.friends,
    required this.incomingRequests,
    required this.outgoingRequests,
  });
}

class FriendsConnectivityUpdated extends FriendsEvent {
  final bool isOffline;

  FriendsConnectivityUpdated(this.isOffline);
}

class LoadBlockedUsers extends FriendsEvent {}

class UnblockUserRequested extends FriendsEvent {
  final String targetUid;
  UnblockUserRequested(this.targetUid);
}
