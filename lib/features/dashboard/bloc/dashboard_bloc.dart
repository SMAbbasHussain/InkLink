import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import '../../../domain/models/board.dart';
import '../../../domain/repositories/board/board_repository.dart';

// States
abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final List<Board> ownedBoards;
  final List<Board> joinedBoards;
  final String? actionError;
  final String? joinedBoardId;

  DashboardLoaded({
    required this.ownedBoards,
    required this.joinedBoards,
    this.actionError,
    this.joinedBoardId,
  });

  DashboardLoaded copyWith({
    List<Board>? ownedBoards,
    List<Board>? joinedBoards,
    Object? actionError = _unset,
    Object? joinedBoardId = _unset,
  }) {
    return DashboardLoaded(
      ownedBoards: ownedBoards ?? this.ownedBoards,
      joinedBoards: joinedBoards ?? this.joinedBoards,
      actionError: actionError == _unset
          ? this.actionError
          : actionError as String?,
      joinedBoardId: joinedBoardId == _unset
          ? this.joinedBoardId
          : joinedBoardId as String?,
    );
  }
}

// Events
abstract class DashboardEvent {}

class _UpdateDashboardData extends DashboardEvent {
  final List<Board> owned;
  final List<Board> joined;

  _UpdateDashboardData(this.owned, this.joined);
}

class DashboardJoinBoardRequested extends DashboardEvent {
  final String boardId;

  DashboardJoinBoardRequested(this.boardId);
}

class DashboardRenameBoardRequested extends DashboardEvent {
  final String boardId;
  final String newName;

  DashboardRenameBoardRequested(this.boardId, this.newName);
}

class DashboardDeleteBoardRequested extends DashboardEvent {
  final String boardId;

  DashboardDeleteBoardRequested(this.boardId);
}

class DashboardConsumeEffects extends DashboardEvent {
  DashboardConsumeEffects();
}

class LoadDashboardRequested extends DashboardEvent {}

const Object _unset = Object();

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final BoardRepository boardRepo;
  StreamSubscription<List<List<Board>>>? _dashboardSub;

  DashboardBloc({required this.boardRepo}) : super(DashboardInitial()) {
    on<LoadDashboardRequested>(_onLoadDashboardRequested);
    on<_UpdateDashboardData>(_onUpdateDashboardData);
    on<DashboardJoinBoardRequested>(_onDashboardJoinBoardRequested);
    on<DashboardRenameBoardRequested>(_onDashboardRenameBoardRequested);
    on<DashboardDeleteBoardRequested>(_onDashboardDeleteBoardRequested);
    on<DashboardConsumeEffects>(_onDashboardConsumeEffects);
  }

  Future<void> _onLoadDashboardRequested(
    LoadDashboardRequested event,
    Emitter<DashboardState> emit,
  ) async {
    _dashboardSub?.cancel();
    await boardRepo.startBoardsSync();

    _dashboardSub =
        Rx.combineLatest2<List<Board>, List<Board>, List<List<Board>>>(
          boardRepo.getOwnedBoards(),
          boardRepo.getJoinedBoards(),
          (owned, joined) => <List<Board>>[owned, joined],
        ).listen((combined) {
          add(_UpdateDashboardData(combined[0], combined[1]));
        });
  }

  void _onUpdateDashboardData(
    _UpdateDashboardData event,
    Emitter<DashboardState> emit,
  ) {
    final current = state;
    if (current is DashboardLoaded) {
      emit(
        current.copyWith(
          ownedBoards: event.owned,
          joinedBoards: event.joined,
          actionError: null,
        ),
      );
      return;
    }

    emit(DashboardLoaded(ownedBoards: event.owned, joinedBoards: event.joined));
  }

  Future<void> _onDashboardJoinBoardRequested(
    DashboardJoinBoardRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      await boardRepo.joinBoard(event.boardId);
      final current = state;
      if (current is DashboardLoaded) {
        emit(current.copyWith(joinedBoardId: event.boardId, actionError: null));
      }
    } catch (e) {
      final current = state;
      if (current is DashboardLoaded) {
        emit(current.copyWith(actionError: 'Failed to join: $e'));
      }
    }
  }

  Future<void> _onDashboardRenameBoardRequested(
    DashboardRenameBoardRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      await boardRepo.renameBoard(event.boardId, event.newName);
      final current = state;
      if (current is DashboardLoaded) {
        emit(current.copyWith(actionError: null));
      }
    } catch (e) {
      final current = state;
      if (current is DashboardLoaded) {
        emit(current.copyWith(actionError: 'Failed to rename board: $e'));
      }
    }
  }

  Future<void> _onDashboardDeleteBoardRequested(
    DashboardDeleteBoardRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      await boardRepo.deleteBoard(event.boardId);
      final current = state;
      if (current is DashboardLoaded) {
        emit(current.copyWith(actionError: null));
      }
    } catch (e) {
      final current = state;
      if (current is DashboardLoaded) {
        emit(current.copyWith(actionError: 'Failed to delete board: $e'));
      }
    }
  }

  void _onDashboardConsumeEffects(
    DashboardConsumeEffects event,
    Emitter<DashboardState> emit,
  ) {
    final current = state;
    if (current is DashboardLoaded) {
      emit(current.copyWith(actionError: null, joinedBoardId: null));
    }
  }

  @override
  Future<void> close() {
    _dashboardSub?.cancel();
    return super.close();
  }
}
