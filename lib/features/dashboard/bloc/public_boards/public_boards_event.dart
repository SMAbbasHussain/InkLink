import '../../../../domain/models/board.dart';

abstract class PublicBoardsEvent {
  const PublicBoardsEvent();
}

class PublicBoardsFetchStarted extends PublicBoardsEvent {
  const PublicBoardsFetchStarted();
}

class PublicBoardsTagSelected extends PublicBoardsEvent {
  final String? tag;

  const PublicBoardsTagSelected(this.tag);
}

class PublicBoardsSortChanged extends PublicBoardsEvent {
  final PublicBoardSort sort;

  const PublicBoardsSortChanged(this.sort);
}

class PublicBoardsSearchChanged extends PublicBoardsEvent {
  final String query;

  const PublicBoardsSearchChanged(this.query);
}

class PublicBoardsLoadMore extends PublicBoardsEvent {
  const PublicBoardsLoadMore();
}

class PublicBoardsRefreshRequested extends PublicBoardsEvent {
  const PublicBoardsRefreshRequested();
}

class PublicBoardsRequestJoinAccess extends PublicBoardsEvent {
  final String boardId;
  final String? message;

  const PublicBoardsRequestJoinAccess(this.boardId, {this.message});
}

class PublicBoardsRequestEditAccess extends PublicBoardsEvent {
  final String boardId;
  final String? message;

  const PublicBoardsRequestEditAccess(this.boardId, {this.message});
}

class PublicBoardsJoinBoard extends PublicBoardsEvent {
  final String boardId;
  final String? boardTitle;

  const PublicBoardsJoinBoard(this.boardId, {this.boardTitle});
}

class PublicBoardsUserPreferencesChanged extends PublicBoardsEvent {
  final List<String> preferredTags;

  const PublicBoardsUserPreferencesChanged(this.preferredTags);
}

