import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/board_preview_preferences.dart';
import '../../domain/services/settings/settings_service.dart';
import '../domain/models/web_account_settings.dart';
import '../domain/services/web_companion_service.dart';

class WebSettingsState {
  final bool loading;
  final String? error;
  final bool trayTips;
  final String quality;
  final bool compression;
  final bool pushEnabled;
  final bool inviteAlertsEnabled;
  final bool friendAlertsEnabled;
  final WebAccountSettings accountSettings;

  const WebSettingsState({
    this.loading = true,
    this.error,
    this.trayTips = true,
    this.quality = BoardPreviewPreferences.medium,
    this.compression = true,
    this.pushEnabled = true,
    this.inviteAlertsEnabled = true,
    this.friendAlertsEnabled = true,
    this.accountSettings = WebAccountSettings.defaults,
  });

  WebSettingsState copyWith({
    bool? loading,
    String? Function()? error,
    bool? trayTips,
    String? quality,
    bool? compression,
    bool? pushEnabled,
    bool? inviteAlertsEnabled,
    bool? friendAlertsEnabled,
    WebAccountSettings? accountSettings,
  }) => WebSettingsState(
    loading: loading ?? this.loading,
    error: error != null ? error() : this.error,
    trayTips: trayTips ?? this.trayTips,
    quality: quality ?? this.quality,
    compression: compression ?? this.compression,
    pushEnabled: pushEnabled ?? this.pushEnabled,
    inviteAlertsEnabled: inviteAlertsEnabled ?? this.inviteAlertsEnabled,
    friendAlertsEnabled: friendAlertsEnabled ?? this.friendAlertsEnabled,
    accountSettings: accountSettings ?? this.accountSettings,
  );
}

/// Manages browser canvas/alert preferences (via [SettingsService]) and account
/// privacy/tag settings (via [WebCompanionService]) so `WebSettingsPage` stays
/// strictly presentational with zero repository or storage imports.
class WebSettingsCubit extends Cubit<WebSettingsState> {
  final WebCompanionService _companionService;
  final SettingsService _settingsService;
  StreamSubscription<WebAccountSettings>? _accountSub;

  WebSettingsCubit({
    required this._companionService,
    required this._settingsService,
  }) : super(const WebSettingsState()) {
    rebind();
  }

  String? get _uid => _companionService.currentUser?.uid;

  void rebind() {
    _accountSub?.cancel();
    _accountSub = _companionService.watchAccountSettings().listen((settings) {
      if (!isClosed) {
        emit(state.copyWith(accountSettings: settings));
      }
    });
    load();
  }

  Future<void> load() async {
    try {
      final trayTips = await _settingsService.getShowTrayTips();
      final quality = await _settingsService.getBoardPreviewQuality();
      final compression = await _settingsService
          .getBoardPreviewCompressionEnabled();
      final push = await _settingsService.getPushNotificationsEnabled(_uid);
      final invite = await _settingsService.getInviteAlertsEnabled(_uid);
      final friend = await _settingsService.getFriendAlertsEnabled(_uid);
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          error: () => null,
          trayTips: trayTips,
          quality: quality,
          compression: compression,
          pushEnabled: push,
          inviteAlertsEnabled: invite,
          friendAlertsEnabled: friend,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: () => e.toString()));
    }
  }

  Future<void> setShowTrayTips(bool value) async {
    emit(state.copyWith(trayTips: value));
    await _settingsService.setShowTrayTips(value);
  }

  Future<void> setBoardPreviewQuality(String value) async {
    emit(state.copyWith(quality: value));
    await _settingsService.setBoardPreviewQuality(value);
  }

  Future<void> setBoardPreviewCompressionEnabled(bool value) async {
    emit(state.copyWith(compression: value));
    await _settingsService.setBoardPreviewCompressionEnabled(value);
  }

  Future<void> setPushNotificationsEnabled(bool value) async {
    emit(state.copyWith(pushEnabled: value));
    await _settingsService.setPushNotificationsEnabled(value, _uid);
  }

  Future<void> setInviteAlertsEnabled(bool value) async {
    emit(state.copyWith(inviteAlertsEnabled: value));
    await _settingsService.setInviteAlertsEnabled(value, _uid);
  }

  Future<void> setFriendAlertsEnabled(bool value) async {
    emit(state.copyWith(friendAlertsEnabled: value));
    await _settingsService.setFriendAlertsEnabled(value, _uid);
  }

  Future<void> clearLocalCache() => _settingsService.clearLocalCache();

  Future<void> updatePrivacy({
    bool? isProfilePublic,
    bool? showOnlineStatus,
    bool? showEmail,
  }) async {
    final previous = state.accountSettings;
    final next = previous.copyWith(
      isProfilePublic: isProfilePublic,
      showOnlineStatus: showOnlineStatus,
      showEmail: showEmail,
    );
    emit(state.copyWith(accountSettings: next));
    try {
      await _companionService.updatePrivacySettings(
        isProfilePublic: next.isProfilePublic,
        showOnlineStatus: next.showOnlineStatus,
        showEmail: next.showEmail,
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(accountSettings: previous));
      rethrow;
    }
  }

  Future<void> togglePreferredTag(String tag) async {
    final previous = state.accountSettings;
    final next = previous.copyWith(
      preferredTags: WebAccountSettings.toggleTag(previous.preferredTags, tag),
    );
    emit(state.copyWith(accountSettings: next));
    try {
      await _companionService.updatePreferredTags(next.preferredTags);
    } catch (_) {
      if (!isClosed) emit(state.copyWith(accountSettings: previous));
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    await _accountSub?.cancel();
    return super.close();
  }
}
