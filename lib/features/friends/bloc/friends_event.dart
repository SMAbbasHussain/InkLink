abstract class FriendsEvent {}

class LoadFriendsInfo extends FriendsEvent {}

class SearchUserByEmailRequested extends FriendsEvent {
  final String email;
  SearchUserByEmailRequested(this.email);
}

class SendFriendRequestRequested extends FriendsEvent {
  final String targetUid;
  SendFriendRequestRequested(this.targetUid);
}

class AcceptFriendRequestRequested extends FriendsEvent {
  final String requestId;
  final String senderUid;
  AcceptFriendRequestRequested(this.requestId, this.senderUid);
}

class DeclineFriendRequestRequested extends FriendsEvent {
  final String requestId;
  DeclineFriendRequestRequested(this.requestId);
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
