import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/settings/settings_repository.dart';

abstract class SettingsEvent {
  const SettingsEvent();
}

class SettingsLoadRequested extends SettingsEvent {
  const SettingsLoadRequested();
}

class SettingsTrayTipsToggled extends SettingsEvent {
  final bool value;

  const SettingsTrayTipsToggled(this.value);
}

class SettingsClearCacheRequested extends SettingsEvent {
  const SettingsClearCacheRequested();
}

class SettingsConsumeMessage extends SettingsEvent {
  const SettingsConsumeMessage();
}

class SettingsState {
  final bool showTrayTips;
  final bool isLoadingTrayTips;
  final String? message;
  final bool isError;

  const SettingsState({
    this.showTrayTips = true,
    this.isLoadingTrayTips = true,
    this.message,
    this.isError = false,
  });

  SettingsState copyWith({
    bool? showTrayTips,
    bool? isLoadingTrayTips,
    Object? message = _unset,
    bool? isError,
  }) {
    return SettingsState(
      showTrayTips: showTrayTips ?? this.showTrayTips,
      isLoadingTrayTips: isLoadingTrayTips ?? this.isLoadingTrayTips,
      message: message == _unset ? this.message : message as String?,
      isError: isError ?? this.isError,
    );
  }
}

const Object _unset = Object();

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository _settingsRepository;

  SettingsBloc({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository,
      super(const SettingsState()) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<SettingsTrayTipsToggled>(_onTrayTipsToggled);
    on<SettingsClearCacheRequested>(_onClearCacheRequested);
    on<SettingsConsumeMessage>(_onConsumeMessage);
  }

  Future<void> _onLoadRequested(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final value = await _settingsRepository.getShowTrayTips();
    emit(state.copyWith(showTrayTips: value, isLoadingTrayTips: false));
  }

  Future<void> _onTrayTipsToggled(
    SettingsTrayTipsToggled event,
    Emitter<SettingsState> emit,
  ) async {
    emit(
      state.copyWith(showTrayTips: event.value, message: null, isError: false),
    );
    await _settingsRepository.setShowTrayTips(event.value);
    emit(
      state.copyWith(
        message: event.value
            ? 'Canvas tray tips enabled.'
            : 'Canvas tray tips disabled.',
        isError: false,
      ),
    );
  }

  Future<void> _onClearCacheRequested(
    SettingsClearCacheRequested event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _settingsRepository.clearLocalCache();
      emit(
        state.copyWith(
          message: 'Local cache cleared successfully.',
          isError: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(message: 'Failed to clear local cache.', isError: true),
      );
    }
  }

  void _onConsumeMessage(
    SettingsConsumeMessage event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(message: null, isError: false));
  }
}
