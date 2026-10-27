import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/models/board.dart';
import '../../../../domain/services/board/board_service.dart';
import '../../../../domain/services/profile/profile_service.dart';
import 'public_boards_event.dart';
import 'public_boards_state.dart';

class PublicBoardsBloc extends Bloc<PublicBoardsEvent, PublicBoardsState> {
  final BoardService _boardService;
  final ProfileService _profileService;
  StreamSubscription<Map<String, dynamic>?>? _userProfileSub;

  PublicBoardsBloc({
    required BoardService boardService,
    required ProfileService profileService,
  })  : _boardService = boardService,
        _profileService = profileService,
        super(const PublicBoardsState()) {
    on<PublicBoardsFetchStarted>(_onFetchStarted);
    on<PublicBoardsRefreshRequested>(_onRefreshRequested);
    on<PublicBoardsTagSelected>(_onTagSelected);
    on<PublicBoardsSortChanged>(_onSortChanged);
    on<PublicBoardsSearchChanged>(_onSearchChanged);
    on<PublicBoardsLoadMore>(_onLoadMore);
    on<PublicBoardsRequestJoinAccess>(_onRequestJoinAccess);
    on<PublicBoardsRequestEditAccess>(_onRequestEditAccess);
    on<PublicBoardsJoinBoard>(_onJoinBoard);
    on<PublicBoardsUserPreferencesChanged>(_onUserPreferencesChanged);
  }

  @override
  Future<void> close() {
    _userProfileSub?.cancel();
    return super.close();
  }

  Future<void> _onFetchStarted(
    PublicBoardsFetchStarted event,
    Emitter<PublicBoardsState> emit,
  ) async {
    emit(state.copyWith(status: PublicBoardsStatus.loading, clearError: true));
    await _loadInitialData(emit);
  }

  Future<void> _onRefreshRequested(
    PublicBoardsRefreshRequested event,
    Emitter<PublicBoardsState> emit,
  ) async {
    await _loadInitialData(emit);
  }

  Future<void> _loadInitialData(Emitter<PublicBoardsState> emit) async {
    try {
      // 1. Load user preferred tags
      List<String> preferredTags = const [];
      try {
        final userData = await _profileService.getCurrentUserData();
        if (userData != null && userData['preferredTags'] is List) {
          preferredTags = List<String>.from(userData['preferredTags']);
        }
      } catch (_) {
        // Fallback to empty preferred tags
      }

      // Start reactive listener for preferred tags (FR14-10)
      final uid = _profileService.getCurrentUserId();
      if (uid != null && _userProfileSub == null) {
        _userProfileSub = _profileService.watchUserById(uid).listen((userData) {
          if (userData != null && userData['preferredTags'] is List) {
            final tags = List<String>.from(userData['preferredTags']);
            add(PublicBoardsUserPreferencesChanged(tags));
          }
        }, onError: (_) {});
      }

      // 2. Fetch recommendations if preferred tags exist
      List<Board> recommended = const [];
      if (preferredTags.isNotEmpty) {
        try {
          recommended = await _boardService.getRecommendedPublicBoards(
            preferredTags: preferredTags,
            limit: 6,
          );
        } catch (_) {
          recommended = const [];
        }
      }

      // 3. Fetch first page of public boards
      final page = await _boardService.getPublicBoards(
        tag: state.selectedTag,
        sort: state.sort,
        limit: 15,
      );

      // 4. Gather available tags for discovery filter chips
      final tagsSet = <String>{};
      for (final b in page.boards) {
        tagsSet.addAll(b.tags);
      }
      for (final b in recommended) {
        tagsSet.addAll(b.tags);
      }
      tagsSet.addAll(
        const ['design', 'brainstorm', 'wireframe', 'architecture', 'retro'],
      );

      emit(state.copyWith(
        status: PublicBoardsStatus.success,
        boards: page.boards,
        recommendedBoards: recommended,
        availableTags: tagsSet.toList()..sort(),
        lastDocCursor: page.lastDocCursor,
        hasMore: page.hasMore,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PublicBoardsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onUserPreferencesChanged(
    PublicBoardsUserPreferencesChanged event,
    Emitter<PublicBoardsState> emit,
  ) async {
    try {
      List<Board> recommended = const [];
      if (event.preferredTags.isNotEmpty) {
        recommended = await _boardService.getRecommendedPublicBoards(
          preferredTags: event.preferredTags,
          limit: 6,
        );
      }
      final tagsSet = Set<String>.from(state.availableTags);
      for (final b in recommended) {
        tagsSet.addAll(b.tags);
      }
      emit(state.copyWith(
        recommendedBoards: recommended,
        availableTags: tagsSet.toList()..sort(),
      ));
    } catch (_) {
      // Keep current recommendations if refresh fails
    }
  }

  Future<void> _onTagSelected(
    PublicBoardsTagSelected event,
    Emitter<PublicBoardsState> emit,
  ) async {
    final newTag = (event.tag == state.selectedTag) ? null : event.tag;
    emit(state.copyWith(
      selectedTag: newTag,
      clearSelectedTag: newTag == null,
      status: PublicBoardsStatus.loading,
      clearLastDocCursor: true,
    ));

    try {
      final page = await _boardService.getPublicBoards(
        tag: newTag,
        sort: state.sort,
        limit: 15,
      );

      emit(state.copyWith(
        status: PublicBoardsStatus.success,
        boards: page.boards,
        lastDocCursor: page.lastDocCursor,
        hasMore: page.hasMore,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PublicBoardsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSortChanged(
    PublicBoardsSortChanged event,
    Emitter<PublicBoardsState> emit,
  ) async {
    if (event.sort == state.sort) return;

    emit(state.copyWith(
      sort: event.sort,
      status: PublicBoardsStatus.loading,
      clearLastDocCursor: true,
    ));

    try {
      final page = await _boardService.getPublicBoards(
        tag: state.selectedTag,
        sort: event.sort,
        limit: 15,
      );

      emit(state.copyWith(
        status: PublicBoardsStatus.success,
        boards: page.boards,
        lastDocCursor: page.lastDocCursor,
        hasMore: page.hasMore,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PublicBoardsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onSearchChanged(
    PublicBoardsSearchChanged event,
    Emitter<PublicBoardsState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  Future<void> _onLoadMore(
    PublicBoardsLoadMore event,
    Emitter<PublicBoardsState> emit,
  ) async {
    if (state.isLoadingMore || !state.hasMore || state.lastDocCursor == null) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      final page = await _boardService.getPublicBoards(
        tag: state.selectedTag,
        sort: state.sort,
        lastDocCursor: state.lastDocCursor,
        limit: 15,
      );

      final existingIds = state.boards.map((b) => b.id).toSet();
      final newBoards =
          page.boards.where((b) => !existingIds.contains(b.id)).toList();
      final combined = List<Board>.from(state.boards)..addAll(newBoards);

      final tagsSet = Set<String>.from(state.availableTags);
      for (final b in newBoards) {
        tagsSet.addAll(b.tags);
      }

      emit(state.copyWith(
        boards: combined,
        availableTags: tagsSet.toList()..sort(),
        lastDocCursor: page.lastDocCursor,
        hasMore: page.hasMore,
        isLoadingMore: false,
      ));
    } catch (_) {
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onJoinBoard(
    PublicBoardsJoinBoard event,
    Emitter<PublicBoardsState> emit,
  ) async {
    try {
      await _boardService.joinBoard(event.boardId);
      final title = event.boardTitle != null ? ' "${event.boardTitle}"' : '';
      emit(state.copyWith(
        actionSuccessMessage: 'Joined board$title! Added to your dashboard.',
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onRequestJoinAccess(
    PublicBoardsRequestJoinAccess event,
    Emitter<PublicBoardsState> emit,
  ) async {
    try {
      await _boardService.requestBoardAccess(
        boardId: event.boardId,
        requestType: 'join',
        message: event.message,
      );
      emit(state.copyWith(
        actionSuccessMessage: 'Join request sent to board owner.',
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onRequestEditAccess(
    PublicBoardsRequestEditAccess event,
    Emitter<PublicBoardsState> emit,
  ) async {
    try {
      await _boardService.requestBoardAccess(
        boardId: event.boardId,
        requestType: 'edit',
        message: event.message,
      );
      emit(state.copyWith(
        actionSuccessMessage: 'Edit access request sent to board owner.',
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }
}
