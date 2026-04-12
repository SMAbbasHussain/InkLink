import 'package:flutter/material.dart';

import '../../repositories/theme/theme_repository.dart';

abstract class ThemeService {
  Future<void> saveThemeMode(ThemeMode mode);
  Future<ThemeMode> getThemeMode();
}

class ThemeServiceImpl implements ThemeService {
  final ThemeRepository _themeRepository;

  ThemeServiceImpl({required ThemeRepository themeRepository})
    : _themeRepository = themeRepository;

  @override
  Future<void> saveThemeMode(ThemeMode mode) {
    return _themeRepository.saveThemeMode(mode);
  }

  @override
  Future<ThemeMode> getThemeMode() {
    return _themeRepository.getThemeMode();
  }
}
