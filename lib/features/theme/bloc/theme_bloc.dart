import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/services/theme/theme_service.dart';

// Events
abstract class ThemeEvent {}

class LoadTheme extends ThemeEvent {}

class ToggleTheme extends ThemeEvent {}

class ThemeBloc extends Bloc<ThemeEvent, ThemeMode> {
  final ThemeService _themeService;

  // FIX: Use initialMode parameter instead of hardcoding ThemeMode.system
  // This ensures the app starts with the user's saved theme preference
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
      final newMode = state == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
      await _themeService.saveThemeMode(newMode);
      emit(newMode);
    });
  }
}
