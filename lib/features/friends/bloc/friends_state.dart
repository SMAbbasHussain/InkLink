abstract class FriendsState {}

/// The initial state when the screen first loads.
class FriendsInitial extends FriendsState {}

/// Show a loading spinner during searches or transactions.
class FriendsLoading extends FriendsState {}

/// The "Active" state. This holds the current data for the UI.
class FriendsLoaded extends FriendsState {
  final List<Map<String, dynamic>> friends;
  final List<Map<String, dynamic>> incomingRequests;

  FriendsLoaded({required this.friends, required this.incomingRequests});
}

/// Specifically used to display the results of a global email search.
class SearchResultsLoaded extends FriendsState {
  final List<Map<String, dynamic>> results;
  SearchResultsLoaded(this.results);
}

/// Used to trigger SnackBars for errors (like "User not found").
class FriendsError extends FriendsState {
  final String message;
  FriendsError(this.message);
}
