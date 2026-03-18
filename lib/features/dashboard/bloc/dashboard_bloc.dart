import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/models/board.dart';
import '../../../domain/repositories/board_repository.dart';

// States
abstract class DashboardState {}
class DashboardInitial extends DashboardState {}
class DashboardLoaded extends DashboardState {
  final List<Board> ownedBoards;
  final List<Board> joinedBoards;
  DashboardLoaded({required this.ownedBoards, required this.joinedBoards});
}

// Events
abstract class DashboardEvent {}
class _UpdateDashboardData extends DashboardEvent {
  final List<Board> owned;
  final List<Board> joined;
  _UpdateDashboardData(this.owned, this.joined);
}
class LoadDashboardRequested extends DashboardEvent {}

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final BoardRepository boardRepo;
  StreamSubscription? _dashboardSub;

  DashboardBloc({required this.boardRepo}) : super(DashboardInitial()) {
    on<LoadDashboardRequested>((event, emit) {
      _dashboardSub?.cancel();
      
      // We listen to the Repository streams here (Only 1 subscription total!)
      // Using RxDart 'combineLatest2' is ideal here
      _dashboardSub = boardRepo.getOwnedBoards().listen((owned) {
        boardRepo.getJoinedBoards().first.then((joined) {
           add(_UpdateDashboardData(owned, joined));
        });
      });
    });

    on<_UpdateDashboardData>((event, emit) {
      emit(DashboardLoaded(ownedBoards: event.owned, joinedBoards: event.joined));
    });
  }

  @override
  Future<void> close() {
    _dashboardSub?.cancel();
    return super.close();
  }
}