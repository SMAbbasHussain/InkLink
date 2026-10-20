import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/settings/settings_service.dart';
import '../../../domain/services/profile/profile_service.dart';

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

class SettingsPrivacyChanged extends SettingsEvent {
  final bool? isProfilePublic;
  final bool? showOnlineStatus;
  final bool? showEmail;

  const SettingsPrivacyChanged({
    this.isProfilePublic,
    this.showOnlineStatus,
    this.showEmail,
  });
}

class SettingsPreferredTagsChanged extends SettingsEvent {
  final List<String> tags;

  const SettingsPreferredTagsChanged(this.tags);
}

class SettingsNotificationPreferencesChanged extends SettingsEvent {
  final bool? pushNotificationsEnabled;
  final bool? inviteAlertsEnabled;
  final bool? friendAlertsEnabled;

  const SettingsNotificationPreferencesChanged({
    this.pushNotificationsEnabled,
    this.inviteAlertsEnabled,
    this.friendAlertsEnabled,
  });
}

class SettingsConsumeMessage extends SettingsEvent {
  const SettingsConsumeMessage();
}

class SettingsState {
  final bool showTrayTips;
  final bool isLoadingTrayTips;
  final String boardPreviewQuality;
  final bool boardPreviewCompressionEnabled;
  final bool isProfilePublic;
  final bool showOnlineStatus;
  final bool showEmail;
  final List<String> preferredTags;
  final bool pushNotificationsEnabled;
  final bool inviteAlertsEnabled;
  final bool friendAlertsEnabled;
  final bool isLoadingProfilePreferences;
  final String? message;
  final bool isError;

  const SettingsState({
    this.showTrayTips = true,
    this.isLoadingTrayTips = true,
    this.boardPreviewQuality = 'medium',
    this.boardPreviewCompressionEnabled = true,
    this.isProfilePublic = true,
    this.showOnlineStatus = true,
    this.showEmail = false,
    this.preferredTags = const [],
    this.pushNotificationsEnabled = true,
    this.inviteAlertsEnabled = true,
    this.friendAlertsEnabled = true,
    this.isLoadingProfilePreferences = true,
    this.message,
    this.isError = false,
  });

  SettingsState copyWith({
    bool? showTrayTips,
    bool? isLoadingTrayTips,
    String? boardPreviewQuality,
    bool? boardPreviewCompressionEnabled,
    bool? isProfilePublic,
    bool? showOnlineStatus,
    bool? showEmail,
    List<String>? preferredTags,
    bool? pushNotificationsEnabled,
    bool? inviteAlertsEnabled,
    bool? friendAlertsEnabled,
    bool? isLoadingProfilePreferences,
    Object? message = _unset,
    bool? isError,
  }) {
    return SettingsState(
      showTrayTips: showTrayTips ?? this.showTrayTips,
      isLoadingTrayTips: isLoadingTrayTips ?? this.isLoadingTrayTips,
      boardPreviewQuality: boardPreviewQuality ?? this.boardPreviewQuality,
      boardPreviewCompressionEnabled:
          boardPreviewCompressionEnabled ?? this.boardPreviewCompressionEnabled,
      isProfilePublic: isProfilePublic ?? this.isProfilePublic,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      showEmail: showEmail ?? this.showEmail,
      preferredTags: preferredTags ?? this.preferredTags,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      inviteAlertsEnabled: inviteAlertsEnabled ?? this.inviteAlertsEnabled,
      friendAlertsEnabled: friendAlertsEnabled ?? this.friendAlertsEnabled,
      isLoadingProfilePreferences:
          isLoadingProfilePreferences ?? this.isLoadingProfilePreferences,
      message: message == _unset ? this.message : message as String?,
      isError: isError ?? this.isError,
    );
  }
}

const Object _unset = Object();

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsService _settingsService;
  final ProfileService? _profileService;

  SettingsBloc({
    required SettingsService settingsService,
    ProfileService? profileService,
  })  : _settingsService = settingsService,
        _profileService = profileService,
        super(const SettingsState()) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<SettingsTrayTipsToggled>(_onTrayTipsToggled);
    on<SettingsClearCacheRequested>(_onClearCacheRequested);
    on<SettingsBoardPreviewQualityChanged>(_onBoardPreviewQualityChanged);
    on<SettingsBoardPreviewCompressionToggled>(
      _onBoardPreviewCompressionToggled,
    );
    on<SettingsPrivacyChanged>(_onPrivacyChanged);
    on<SettingsPreferredTagsChanged>(_onPreferredTagsChanged);
    on<SettingsNotificationPreferencesChanged>(_onNotificationPreferencesChanged);
    on<SettingsConsumeMessage>(_onConsumeMessage);
  }

  Future<void> _onLoadRequested(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final value = await _settingsService.getShowTrayTips();
    final quality = await _settingsService.getBoardPreviewQuality();
    final compression =
        await _settingsService.getBoardPreviewCompressionEnabled();
    final pushEnabled = await _settingsService.getPushNotificationsEnabled();
    final inviteEnabled = await _settingsService.getInviteAlertsEnabled();
    final friendEnabled = await _settingsService.getFriendAlertsEnabled();

    bool isProfilePublic = state.isProfilePublic;
    bool showOnlineStatus = state.showOnlineStatus;
    bool showEmail = state.showEmail;
    List<String> preferredTags = state.preferredTags;
    bool pushNotificationsEnabled = pushEnabled;
    bool inviteAlertsEnabled = inviteEnabled;
    bool friendAlertsEnabled = friendEnabled;

    if (_profileService != null) {
      try {
        final userData = await _profileService.getCurrentUserData();
        if (userData != null) {
          isProfilePublic = (userData['isProfilePublic'] as bool?) ?? true;
          showOnlineStatus = (userData['showOnlineStatus'] as bool?) ?? true;
          showEmail = (userData['showEmail'] as bool?) ?? false;
          preferredTags = (userData['preferredTags'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              preferredTags;

          final notifPrefs = userData['notificationPreferences'];
          if (notifPrefs is Map<String, dynamic>) {
            if (notifPrefs.containsKey('pushNotificationsEnabled')) {
              pushNotificationsEnabled =
                  (notifPrefs['pushNotificationsEnabled'] as bool?) ?? pushEnabled;
              await _settingsService
                  .setPushNotificationsEnabled(pushNotificationsEnabled);
            }
            if (notifPrefs.containsKey('inviteAlertsEnabled')) {
              inviteAlertsEnabled =
                  (notifPrefs['inviteAlertsEnabled'] as bool?) ?? inviteEnabled;
              await _settingsService.setInviteAlertsEnabled(inviteAlertsEnabled);
            }
            if (notifPrefs.containsKey('friendAlertsEnabled')) {
              friendAlertsEnabled =
                  (notifPrefs['friendAlertsEnabled'] as bool?) ?? friendEnabled;
              await _settingsService.setFriendAlertsEnabled(friendAlertsEnabled);
            }
          }
        }
      } catch (_) {}
    }

    emit(
      state.copyWith(
        showTrayTips: value,
        boardPreviewQuality: quality,
        boardPreviewCompressionEnabled: compression,
        isLoadingTrayTips: false,
        isProfilePublic: isProfilePublic,
        showOnlineStatus: showOnlineStatus,
        showEmail: showEmail,
        preferredTags: preferredTags,
        pushNotificationsEnabled: pushNotificationsEnabled,
        inviteAlertsEnabled: inviteAlertsEnabled,
        friendAlertsEnabled: friendAlertsEnabled,
        isLoadingProfilePreferences: false,
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

  Future<void> _onPrivacyChanged(
    SettingsPrivacyChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final newIsPublic = event.isProfilePublic ?? state.isProfilePublic;
    final newShowOnline = event.showOnlineStatus ?? state.showOnlineStatus;
    final newShowEmail = event.showEmail ?? state.showEmail;

    emit(
      state.copyWith(
        isProfilePublic: newIsPublic,
        showOnlineStatus: newShowOnline,
        showEmail: newShowEmail,
      ),
    );

    if (_profileService != null) {
      try {
        await _profileService.updatePrivacySettings(
          isProfilePublic: newIsPublic,
          showOnlineStatus: newShowOnline,
          showEmail: newShowEmail,
        );
        emit(
          state.copyWith(
            message: 'Privacy settings updated.',
            isError: false,
          ),
        );
      } catch (e) {
        emit(
          state.copyWith(
            message: 'Failed to update privacy settings.',
            isError: true,
          ),
        );
      }
    }
  }

  Future<void> _onPreferredTagsChanged(
    SettingsPreferredTagsChanged event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(preferredTags: event.tags));

    if (_profileService != null) {
      try {
        await _profileService.updatePreferredTags(event.tags);
        emit(
          state.copyWith(
            message: 'Content preferences updated.',
            isError: false,
          ),
        );
      } catch (e) {
        emit(
          state.copyWith(
            message: 'Failed to update content preferences.',
            isError: true,
          ),
        );
      }
    }
  }

  Future<void> _onNotificationPreferencesChanged(
    SettingsNotificationPreferencesChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final newPush =
        event.pushNotificationsEnabled ?? state.pushNotificationsEnabled;
    final newInvite =
        event.inviteAlertsEnabled ?? state.inviteAlertsEnabled;
    final newFriend =
        event.friendAlertsEnabled ?? state.friendAlertsEnabled;

    emit(
      state.copyWith(
        pushNotificationsEnabled: newPush,
        inviteAlertsEnabled: newInvite,
        friendAlertsEnabled: newFriend,
        message: null,
        isError: false,
      ),
    );

    if (event.pushNotificationsEnabled != null) {
      await _settingsService.setPushNotificationsEnabled(newPush);
    }
    if (event.inviteAlertsEnabled != null) {
      await _settingsService.setInviteAlertsEnabled(newInvite);
    }
    if (event.friendAlertsEnabled != null) {
      await _settingsService.setFriendAlertsEnabled(newFriend);
    }

    if (_profileService != null) {
      try {
        await _profileService.updateNotificationPreferences(
          pushNotificationsEnabled: event.pushNotificationsEnabled,
          inviteAlertsEnabled: event.inviteAlertsEnabled,
          friendAlertsEnabled: event.friendAlertsEnabled,
        );
      } catch (_) {}
    }

    emit(
      state.copyWith(
        message: 'Notification preferences updated.',
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
