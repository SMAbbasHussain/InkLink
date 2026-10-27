import '../../../../domain/models/board.dart';

enum PublicBoardsStatus {
  initial,
  loading,
  success,
  failure,
}

class PublicBoardsState {
  final PublicBoardsStatus status;
  final List<Board> boards;
  final List<Board> recommendedBoards;
  final List<String> availableTags;
  final String? selectedTag;
  final PublicBoardSort sort;
  final String searchQuery;
  final dynamic lastDocCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const PublicBoardsState({
    this.status = PublicBoardsStatus.initial,
    this.boards = const [],
    this.recommendedBoards = const [],
    this.availableTags = const [],
    this.selectedTag,
    this.sort = PublicBoardSort.recent,
    this.searchQuery = '',
    this.lastDocCursor,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  /// Filtered boards based on search query in memory for instantaneous matching
  List<Board> get filteredBoards {
    if (searchQuery.trim().isEmpty) {
      return boards;
    }
    final query = searchQuery.trim().toLowerCase();
    return boards.where((board) {
      final matchesTitle = board.title.toLowerCase().contains(query);
      final matchesTags =
          board.tags.any((t) => t.toLowerCase().contains(query));
      return matchesTitle || matchesTags;
    }).toList();
  }

  PublicBoardsState copyWith({
    PublicBoardsStatus? status,
    List<Board>? boards,
    List<Board>? recommendedBoards,
    List<String>? availableTags,
    String? selectedTag,
    bool clearSelectedTag = false,
    PublicBoardSort? sort,
    String? searchQuery,
    dynamic lastDocCursor,
    bool clearLastDocCursor = false,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    String? actionSuccessMessage,
    bool clearActionMessage = false,
  }) {
    return PublicBoardsState(
      status: status ?? this.status,
      boards: boards ?? this.boards,
      recommendedBoards: recommendedBoards ?? this.recommendedBoards,
      availableTags: availableTags ?? this.availableTags,
      selectedTag:
          clearSelectedTag ? null : (selectedTag ?? this.selectedTag),
      sort: sort ?? this.sort,
      searchQuery: searchQuery ?? this.searchQuery,
      lastDocCursor:
          clearLastDocCursor ? null : (lastDocCursor ?? this.lastDocCursor),
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actionSuccessMessage: clearActionMessage
          ? null
          : (actionSuccessMessage ?? this.actionSuccessMessage),
    );
  }
}
