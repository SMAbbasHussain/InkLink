import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import '../../../domain/models/board.dart';
import '../../../domain/repositories/board/board_repository.dart';
import '../../../domain/repositories/profile/profile_repository.dart';

// States
abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final List<Board> ownedBoards;
  final List<Board> joinedBoards;
  final Map<String, dynamic>? currentUserProfile;
  final String? actionError;
  final String? joinedBoardId;
  final String? createdBoardId;

  DashboardLoaded({
    required this.ownedBoards,
    required this.joinedBoards,
    this.currentUserProfile,
    this.actionError,
    this.joinedBoardId,
    this.createdBoardId,
  });

  DashboardLoaded copyWith({
    List<Board>? ownedBoards,
    List<Board>? joinedBoards,
    Object? currentUserProfile = _unset,
    Object? actionError = _unset,
    Object? joinedBoardId = _unset,
    Object? createdBoardId = _unset,
  }) {
    return DashboardLoaded(
      ownedBoards: ownedBoards ?? this.ownedBoards,
      joinedBoards: joinedBoards ?? this.joinedBoards,
      currentUserProfile: currentUserProfile == _unset
          ? this.currentUserProfile
          : currentUserProfile as Map<String, dynamic>?,
      actionError: actionError == _unset
          ? this.actionError
          : actionError as String?,
      joinedBoardId: joinedBoardId == _unset
          ? this.joinedBoardId
          : joinedBoardId as String?,
      createdBoardId: createdBoardId == _unset
          ? this.createdBoardId
          : createdBoardId as String?,
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

class DashboardCreateBoardRequested extends DashboardEvent {
  final String? title;

  DashboardCreateBoardRequested({this.title});
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

class DashboardWatchCurrentUserProfileRequested extends DashboardEvent {
  final String? userId;

  DashboardWatchCurrentUserProfileRequested(this.userId);
}

class _UpdateCurrentUserProfile extends DashboardEvent {
  final Map<String, dynamic>? userData;

  _UpdateCurrentUserProfile(this.userData);
}

class LoadDashboardRequested extends DashboardEvent {}

const Object _unset = Object();

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final BoardRepository boardRepo;
  final ProfileRepository profileRepo;
  StreamSubscription<List<List<Board>>>? _dashboardSub;
  StreamSubscription<Map<String, dynamic>?>? _profileSub;
  Map<String, dynamic>? _latestCurrentUserProfile;

  DashboardBloc({required this.boardRepo, required this.profileRepo})
    : super(DashboardInitial()) {
    on<LoadDashboardRequested>(_onLoadDashboardRequested);
    on<_UpdateDashboardData>(_onUpdateDashboardData);
    on<DashboardCreateBoardRequested>(_onDashboardCreateBoardRequested);
    on<DashboardJoinBoardRequested>(_onDashboardJoinBoardRequested);
    on<DashboardRenameBoardRequested>(_onDashboardRenameBoardRequested);
    on<DashboardDeleteBoardRequested>(_onDashboardDeleteBoardRequested);
    on<DashboardConsumeEffects>(_onDashboardConsumeEffects);
    on<DashboardWatchCurrentUserProfileRequested>(
      _onDashboardWatchCurrentUserProfileRequested,
    );
    on<_UpdateCurrentUserProfile>(_onUpdateCurrentUserProfile);
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

    emit(
      DashboardLoaded(
        ownedBoards: event.owned,
        joinedBoards: event.joined,
        currentUserProfile: _latestCurrentUserProfile,
      ),
    );
  }

  Future<void> _onDashboardWatchCurrentUserProfileRequested(
    DashboardWatchCurrentUserProfileRequested event,
    Emitter<DashboardState> emit,
  ) async {
    await _profileSub?.cancel();
    _profileSub = null;

    if (event.userId == null || event.userId!.isEmpty) {
      add(_UpdateCurrentUserProfile(null));
      return;
    }

    _profileSub = profileRepo.getUserByIdStream(event.userId!).listen((data) {
      add(_UpdateCurrentUserProfile(data));
    });
  }

  void _onUpdateCurrentUserProfile(
    _UpdateCurrentUserProfile event,
    Emitter<DashboardState> emit,
  ) {
    _latestCurrentUserProfile = event.userData;

    final current = state;
    if (current is DashboardLoaded) {
      emit(current.copyWith(currentUserProfile: event.userData));
    }
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

  Future<void> _onDashboardCreateBoardRequested(
    DashboardCreateBoardRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      final boardId = await boardRepo.createNewBoard(
        event.title ?? 'Untitled Board',
      );

      final current = state;
      if (current is DashboardLoaded) {
        emit(current.copyWith(createdBoardId: boardId, actionError: null));
      }
    } catch (e) {
      final current = state;
      if (current is DashboardLoaded) {
        emit(current.copyWith(actionError: 'Failed to create board: $e'));
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
      emit(
        current.copyWith(
          actionError: null,
          joinedBoardId: null,
          createdBoardId: null,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _dashboardSub?.cancel();
    _profileSub?.cancel();
    return super.close();
  }
}
