import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/theme/theme_repository.dart';

// Events
abstract class ThemeEvent {}

class LoadTheme extends ThemeEvent {}

class ToggleTheme extends ThemeEvent {}

class ThemeBloc extends Bloc<ThemeEvent, ThemeMode> {
  final ThemeRepository themeRepository;

  // FIX: Use initialMode parameter instead of hardcoding ThemeMode.system
  // This ensures the app starts with the user's saved theme preference
  ThemeBloc({required this.themeRepository, required ThemeMode initialMode})
    : super(initialMode) {
    // 1. Load theme from storage on app start
    on<LoadTheme>((event, emit) async {
      final mode = await themeRepository.getThemeMode();
      emit(mode);
    });

    // 2. Toggle between Light and Dark and persist the choice
    on<ToggleTheme>((event, emit) async {
      final newMode = state == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
      await themeRepository.saveThemeMode(newMode);
      emit(newMode);
    });
  }
}
