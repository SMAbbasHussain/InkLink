import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/settings/settings_service.dart';

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

class SettingsBoardPreviewQualityChanged extends SettingsEvent {
  final String quality;

  const SettingsBoardPreviewQualityChanged(this.quality);
}

class SettingsBoardPreviewCompressionToggled extends SettingsEvent {
  final bool enabled;

  const SettingsBoardPreviewCompressionToggled(this.enabled);
}

class SettingsConsumeMessage extends SettingsEvent {
  const SettingsConsumeMessage();
}

class SettingsState {
  final bool showTrayTips;
  final bool isLoadingTrayTips;
  final String boardPreviewQuality;
  final bool boardPreviewCompressionEnabled;
  final String? message;
  final bool isError;

  const SettingsState({
    this.showTrayTips = true,
    this.isLoadingTrayTips = true,
    this.boardPreviewQuality = 'medium',
    this.boardPreviewCompressionEnabled = true,
    this.message,
    this.isError = false,
  });

  SettingsState copyWith({
    bool? showTrayTips,
    bool? isLoadingTrayTips,
    String? boardPreviewQuality,
    bool? boardPreviewCompressionEnabled,
    Object? message = _unset,
    bool? isError,
  }) {
    return SettingsState(
      showTrayTips: showTrayTips ?? this.showTrayTips,
      isLoadingTrayTips: isLoadingTrayTips ?? this.isLoadingTrayTips,
      boardPreviewQuality: boardPreviewQuality ?? this.boardPreviewQuality,
      boardPreviewCompressionEnabled:
          boardPreviewCompressionEnabled ?? this.boardPreviewCompressionEnabled,
      message: message == _unset ? this.message : message as String?,
      isError: isError ?? this.isError,
    );
  }
}

const Object _unset = Object();

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsService _settingsService;

  SettingsBloc({required SettingsService settingsService})
    : _settingsService = settingsService,
      super(const SettingsState()) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<SettingsTrayTipsToggled>(_onTrayTipsToggled);
    on<SettingsClearCacheRequested>(_onClearCacheRequested);
    on<SettingsBoardPreviewQualityChanged>(_onBoardPreviewQualityChanged);
    on<SettingsBoardPreviewCompressionToggled>(
      _onBoardPreviewCompressionToggled,
    );
    on<SettingsConsumeMessage>(_onConsumeMessage);
  }

  Future<void> _onLoadRequested(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final value = await _settingsService.getShowTrayTips();
    final quality = await _settingsService.getBoardPreviewQuality();
    final compression = await _settingsService
        .getBoardPreviewCompressionEnabled();
    emit(
      state.copyWith(
        showTrayTips: value,
        boardPreviewQuality: quality,
        boardPreviewCompressionEnabled: compression,
        isLoadingTrayTips: false,
      ),
    );
  }

  Future<void> _onTrayTipsToggled(
    SettingsTrayTipsToggled event,
    Emitter<SettingsState> emit,
  ) async {
    emit(
      state.copyWith(showTrayTips: event.value, message: null, isError: false),
    );
    await _settingsService.setShowTrayTips(event.value);
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
      await _settingsService.clearLocalCache();
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

  Future<void> _onBoardPreviewQualityChanged(
    SettingsBoardPreviewQualityChanged event,
    Emitter<SettingsState> emit,
  ) async {
    emit(
      state.copyWith(
        boardPreviewQuality: event.quality,
        message: null,
        isError: false,
      ),
    );
    await _settingsService.setBoardPreviewQuality(event.quality);
    emit(
      state.copyWith(message: 'Board preview quality updated.', isError: false),
    );
  }

  Future<void> _onBoardPreviewCompressionToggled(
    SettingsBoardPreviewCompressionToggled event,
    Emitter<SettingsState> emit,
  ) async {
    emit(
      state.copyWith(
        boardPreviewCompressionEnabled: event.enabled,
        message: null,
        isError: false,
      ),
    );
    await _settingsService.setBoardPreviewCompressionEnabled(event.enabled);
    emit(
      state.copyWith(
        message: event.enabled
            ? 'Board preview compression enabled.'
            : 'Board preview compression disabled.',
        isError: false,
      ),
    );
  }

  void _onConsumeMessage(
    SettingsConsumeMessage event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(message: null, isError: false));
  }
}
