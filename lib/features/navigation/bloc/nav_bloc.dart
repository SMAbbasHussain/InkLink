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
  // IMPROVEMENT: Tab selection could be persisted using SharedPreferences
  // to remember the user's last selected tab across app restarts.
  // Implementation would require:
  // 1. Load last saved tab index from SharedPreferences in constructor
  // 2. Save tab index to SharedPreferences on ChangeTab event

  NavBloc() : super(NavState(0)) {
    on<ChangeTab>((event, emit) => emit(NavState(event.index)));
  }
}
