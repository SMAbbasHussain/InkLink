import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/board.dart';
import '../../../domain/services/board/board_service.dart';

// --- Events ---
abstract class BoardSettingsEvent {
  const BoardSettingsEvent();
}

class BoardSettingsStarted extends BoardSettingsEvent {
  final String boardId;
  const BoardSettingsStarted(this.boardId);
}

class _BoardMembersUpdated extends BoardSettingsEvent {
  final List<BoardMember> members;
  const _BoardMembersUpdated(this.members);
}

class _BoardUpdated extends BoardSettingsEvent {
  final Board? board;
  const _BoardUpdated(this.board);
}

class _BoardMembersLoadFailed extends BoardSettingsEvent {
  final String message;
  const _BoardMembersLoadFailed(this.message);
}

class BoardSettingsSearchChanged extends BoardSettingsEvent {
  final String query;
  const BoardSettingsSearchChanged(this.query);
}

class BoardSettingsMemberRoleUpdated extends BoardSettingsEvent {
  final String targetUid;
  final String newRole;
  const BoardSettingsMemberRoleUpdated(this.targetUid, this.newRole);
}

class BoardSettingsMemberRemoved extends BoardSettingsEvent {
  final String targetUid;
  const BoardSettingsMemberRemoved(this.targetUid);
}

class BoardSettingsInviteSubmitted extends BoardSettingsEvent {
  final String rawEmails;
  final String targetRole;

  const BoardSettingsInviteSubmitted({
    required this.rawEmails,
    required this.targetRole,
  });
}

// --- State ---
enum BoardSettingsStatus { initial, loading, success, failure }

class BoardSettingsState {
  final BoardSettingsStatus status;
  final String boardId;
  final Board? board;
  final List<BoardMember> members;
  final String searchQuery;
  final String? errorMessage;
  final String? infoMessage;
  final List<String> unresolvedInviteEmails;
  final bool isOperationLoading;

  const BoardSettingsState({
    this.status = BoardSettingsStatus.initial,
    this.boardId = '',
    this.board,
    this.members = const [],
    this.searchQuery = '',
    this.errorMessage,
    this.infoMessage,
    this.unresolvedInviteEmails = const [],
    this.isOperationLoading = false,
  });

  BoardSettingsState copyWith({
    BoardSettingsStatus? status,
    String? boardId,
    Board? board,
    List<BoardMember>? members,
    String? searchQuery,
    String? errorMessage,
    String? infoMessage,
    List<String>? unresolvedInviteEmails,
    bool? isOperationLoading,
  }) {
    return BoardSettingsState(
      status: status ?? this.status,
      boardId: boardId ?? this.boardId,
      board: board ?? this.board,
      members: members ?? this.members,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
      infoMessage: infoMessage ?? this.infoMessage,
      unresolvedInviteEmails:
          unresolvedInviteEmails ?? this.unresolvedInviteEmails,
      isOperationLoading: isOperationLoading ?? this.isOperationLoading,
    );
  }

  List<BoardMember> get filteredMembers {
    if (searchQuery.trim().isEmpty) return members;
    final query = searchQuery.trim().toLowerCase();
    return members.where((m) {
      final nameMatches = m.displayName?.toLowerCase().contains(query) ?? false;
      final emailMatches = m.email?.toLowerCase().contains(query) ?? false;
      return nameMatches || emailMatches;
    }).toList();
  }
}

// --- BLoC ---
class BoardSettingsBloc extends Bloc<BoardSettingsEvent, BoardSettingsState> {
  final BoardService _boardService;
  StreamSubscription<List<BoardMember>>? _membersSub;
  StreamSubscription<Board?>? _boardSub;

  BoardSettingsBloc({required BoardService boardService})
    : _boardService = boardService,
      super(const BoardSettingsState()) {
    on<BoardSettingsStarted>(_onStarted);
    on<_BoardMembersUpdated>(_onMembersUpdated);
    on<_BoardUpdated>(_onBoardUpdated);
    on<_BoardMembersLoadFailed>(_onMembersLoadFailed);
    on<BoardSettingsSearchChanged>(_onSearchChanged);
    on<BoardSettingsMemberRoleUpdated>(_onMemberRoleUpdated);
    on<BoardSettingsMemberRemoved>(_onMemberRemoved);
    on<BoardSettingsInviteSubmitted>(_onInviteSubmitted);
  }

  void _onStarted(
    BoardSettingsStarted event,
    Emitter<BoardSettingsState> emit,
  ) {
    emit(
      state.copyWith(
        status: BoardSettingsStatus.loading,
        boardId: event.boardId,
      ),
    );

    _boardSub?.cancel();
    _boardSub = _boardService.getBoardById(event.boardId).listen((board) {
      add(_BoardUpdated(board));
    });

    _membersSub?.cancel();
    _membersSub = _boardService
        .getBoardMembers(event.boardId)
        .listen(
          (members) {
            add(_BoardMembersUpdated(members));
          },
          onError: (error) {
            if (!isClosed) {
              add(_BoardMembersLoadFailed(error.toString()));
            }
          },
        );
  }

  void _onBoardUpdated(_BoardUpdated event, Emitter<BoardSettingsState> emit) {
    emit(state.copyWith(board: event.board));
  }

  void _onMembersUpdated(
    _BoardMembersUpdated event,
    Emitter<BoardSettingsState> emit,
  ) {
    emit(
      state.copyWith(
        status: BoardSettingsStatus.success,
        members: event.members,
      ),
    );
  }

  void _onMembersLoadFailed(
    _BoardMembersLoadFailed event,
    Emitter<BoardSettingsState> emit,
  ) {
    emit(
      state.copyWith(
        status: BoardSettingsStatus.failure,
        errorMessage: event.message,
      ),
    );
  }

  void _onSearchChanged(
    BoardSettingsSearchChanged event,
    Emitter<BoardSettingsState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  Future<void> _onMemberRoleUpdated(
    BoardSettingsMemberRoleUpdated event,
    Emitter<BoardSettingsState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          isOperationLoading: true,
          errorMessage: null,
          infoMessage: null,
          unresolvedInviteEmails: const [],
        ),
      );
      await _boardService.updateBoardMemberRole(
        state.boardId,
        event.targetUid,
        event.newRole,
      );
      emit(state.copyWith(isOperationLoading: false));
    } catch (e, stack) {
      developer.log(
        'Failed to update member role',
        name: 'BoardSettingsBloc',
        error: e,
        stackTrace: stack,
      );
      emit(
        state.copyWith(
          isOperationLoading: false,
          errorMessage: 'Failed to update role.',
          unresolvedInviteEmails: const [],
        ),
      );
    }
  }

  Future<void> _onMemberRemoved(
    BoardSettingsMemberRemoved event,
    Emitter<BoardSettingsState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          isOperationLoading: true,
          errorMessage: null,
          infoMessage: null,
          unresolvedInviteEmails: const [],
        ),
      );
      await _boardService.removeBoardMember(state.boardId, event.targetUid);
      emit(state.copyWith(isOperationLoading: false));
    } catch (e, stack) {
      developer.log(
        'Failed to remove member',
        name: 'BoardSettingsBloc',
        error: e,
        stackTrace: stack,
      );
      emit(
        state.copyWith(
          isOperationLoading: false,
          errorMessage: 'Failed to remove member.',
          unresolvedInviteEmails: const [],
        ),
      );
    }
  }

  Future<void> _onInviteSubmitted(
    BoardSettingsInviteSubmitted event,
    Emitter<BoardSettingsState> emit,
  ) async {
    final board = state.board;
    if (board == null) {
      emit(state.copyWith(errorMessage: 'Board not loaded.'));
      return;
    }

    final invitedUserIds = event.rawEmails
        .split(RegExp(r'[\n,;\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (invitedUserIds.isEmpty) {
      emit(state.copyWith(errorMessage: 'Enter at least one email address.'));
      return;
    }

    try {
      emit(
        state.copyWith(
          isOperationLoading: true,
          errorMessage: null,
          infoMessage: null,
          unresolvedInviteEmails: const [],
        ),
      );

      final result = await _boardService.sendBoardInvite(
        boardId: board.id,
        boardTitle: board.title,
        invitedUserIds: invitedUserIds,
        targetRole: event.targetRole,
      );

      if (result.unresolvedEmails.isEmpty) {
        emit(
          state.copyWith(
            isOperationLoading: false,
            infoMessage: 'Invites sent successfully.',
            unresolvedInviteEmails: const [],
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          isOperationLoading: false,
          infoMessage: 'Invites sent with some unresolved emails.',
          unresolvedInviteEmails: result.unresolvedEmails,
        ),
      );
    } catch (e, stack) {
      developer.log(
        'Failed to send invites',
        name: 'BoardSettingsBloc',
        error: e,
        stackTrace: stack,
      );
      emit(
        state.copyWith(
          isOperationLoading: false,
          errorMessage: 'Failed to send invites.',
          unresolvedInviteEmails: const [],
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _boardSub?.cancel();
    _membersSub?.cancel();
    return super.close();
  }
}
