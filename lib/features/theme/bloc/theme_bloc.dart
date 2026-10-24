import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/services/theme/theme_service.dart';

// Events
abstract class ThemeEvent {}

class LoadTheme extends ThemeEvent {}

class ToggleTheme extends ThemeEvent {
  final bool? isCurrentlyDark;
  ToggleTheme({this.isCurrentlyDark});
}

class SetThemeMode extends ThemeEvent {
  final ThemeMode mode;
  SetThemeMode(this.mode);
}

class ThemeBloc extends Bloc<ThemeEvent, ThemeMode> {
  final ThemeService _themeService;

  ThemeBloc({
    required ThemeService themeService,
    required ThemeMode initialMode,
  }) : _themeService = themeService,
       super(initialMode) {
    // 1. Load theme from storage on app start
    on<LoadTheme>((event, emit) async {
      final mode = await _themeService.getThemeMode();
      emit(mode);
    });

    // 2. Toggle between Light and Dark and persist the choice
    on<ToggleTheme>((event, emit) async {
      bool currentlyDark;
      if (event.isCurrentlyDark != null) {
        currentlyDark = event.isCurrentlyDark!;
      } else if (state == ThemeMode.dark) {
        currentlyDark = true;
      } else if (state == ThemeMode.light) {
        currentlyDark = false;
      } else {
        currentlyDark =
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark;
      }

      final newMode = currentlyDark ? ThemeMode.light : ThemeMode.dark;
      await _themeService.saveThemeMode(newMode);
      emit(newMode);
    });

    // 3. Set explicit theme mode
    on<SetThemeMode>((event, emit) async {
      await _themeService.saveThemeMode(event.mode);
      emit(event.mode);
    });
  }
}
