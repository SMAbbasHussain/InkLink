import 'package:flutter_bloc/flutter_bloc.dart';

// Events
abstract class NavEvent {}
class ChangeTab extends NavEvent {
  final int index;
  ChangeTab(this.index);
}

// State
class NavState {
  final int index;
  NavState(this.index);
}

class NavBloc extends Bloc<NavEvent, NavState> {
  NavBloc() : super(NavState(0)) {
    on<ChangeTab>((event, emit) => emit(NavState(event.index)));
  }
}