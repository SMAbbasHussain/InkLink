abstract class FriendsState {}

/// The initial state when the screen first loads.
class FriendsInitial extends FriendsState {}

/// Show a loading spinner during searches or transactions.
class FriendsLoading extends FriendsState {}

/// The "Active" state. This holds the current data for the UI.
class FriendsLoaded extends FriendsState {
  final List<Map<String, dynamic>> friends;
  final List<Map<String, dynamic>> incomingRequests;
  final List<Map<String, dynamic>> outgoingRequests;
  final Set<String> sendingRequestTargetUids;
  final Set<String> acceptingRequestIds;
  final Set<String> decliningRequestIds;
  final Set<String> cancelingRequestIds;
  final bool isOffline;

  FriendsLoaded({
    required this.friends,
    required this.incomingRequests,
    required this.outgoingRequests,
    this.sendingRequestTargetUids = const <String>{},
    this.acceptingRequestIds = const <String>{},
    this.decliningRequestIds = const <String>{},
    this.cancelingRequestIds = const <String>{},
    this.isOffline = false,
  });

  FriendsLoaded copyWith({
    List<Map<String, dynamic>>? friends,
    List<Map<String, dynamic>>? incomingRequests,
    List<Map<String, dynamic>>? outgoingRequests,
    Set<String>? sendingRequestTargetUids,
    Set<String>? acceptingRequestIds,
    Set<String>? decliningRequestIds,
    Set<String>? cancelingRequestIds,
    bool? isOffline,
  }) {
    return FriendsLoaded(
      friends: friends ?? this.friends,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      sendingRequestTargetUids:
          sendingRequestTargetUids ?? this.sendingRequestTargetUids,
      acceptingRequestIds: acceptingRequestIds ?? this.acceptingRequestIds,
      decliningRequestIds: decliningRequestIds ?? this.decliningRequestIds,
      cancelingRequestIds: cancelingRequestIds ?? this.cancelingRequestIds,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

/// Specifically used to display the results of a global email search.
class SearchResultsLoaded extends FriendsState {
  final List<Map<String, dynamic>> results;
  final Set<String> pendingOutgoingTargetUids;
  final bool isOffline;

  SearchResultsLoaded({
    required this.results,
    this.pendingOutgoingTargetUids = const <String>{},
    this.isOffline = false,
  });
}

/// Email search states (separate from main friends list to prevent UI corruption)
class EmailSearchInProgress extends FriendsState {}

/// Results from email search with friend status information
class EmailSearchResultsLoaded extends FriendsState {
  final Map<String, dynamic> result; // Single user (emails are unique)
  final Set<String> friendUids; // Current friends list
  final Set<String> pendingOutgoingUids; // Pending outgoing requests
  final Set<String> sendingRequestTargetUids;
  final bool isOffline;

  EmailSearchResultsLoaded({
    required this.result,
    required this.friendUids,
    required this.pendingOutgoingUids,
    this.sendingRequestTargetUids = const <String>{},
    this.isOffline = false,
  });
}

/// No results from email search
class EmailSearchEmpty extends FriendsState {}

/// Used to trigger SnackBars for errors (like "User not found").
class FriendsError extends FriendsState {
  final String message;
  FriendsError(this.message);
}
