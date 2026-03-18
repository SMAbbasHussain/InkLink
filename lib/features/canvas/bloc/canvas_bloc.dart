import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/board_repository.dart';

// States
abstract class CanvasState {}
class CanvasInitial extends CanvasState {}
class CanvasCreating extends CanvasState {}
class CanvasReady extends CanvasState { final String boardId; CanvasReady(this.boardId); }
class CanvasError extends CanvasState { final String message; CanvasError(this.message); }

// Events
abstract class CanvasEvent {}
class CreateBoardRequested extends CanvasEvent {}

class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  final BoardRepository boardRepo;

  CanvasBloc({required this.boardRepo}) : super(CanvasInitial()) {
    on<CreateBoardRequested>((event, emit) async {
      emit(CanvasCreating());
      try {
        final id = await boardRepo.createNewBoard();
        emit(CanvasReady(id));
      } catch (e) {
        emit(CanvasError(e.toString()));
      }
    });
  }
}