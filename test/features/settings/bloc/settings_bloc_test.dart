import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/services/profile/profile_service.dart';
import 'package:inklink/domain/services/settings/settings_service.dart';
import 'package:inklink/features/settings/bloc/settings_bloc.dart';

class FakeSettingsService implements SettingsService {
  bool showTrayTips = true;
  String boardPreviewQuality = 'medium';
  bool boardPreviewCompressionEnabled = true;
  bool pushNotificationsEnabled = true;
  bool inviteAlertsEnabled = true;
  bool friendAlertsEnabled = true;

  @override
  Future<bool> getShowTrayTips() async => showTrayTips;

  @override
  Future<void> setShowTrayTips(bool value) async {
    showTrayTips = value;
  }

  @override
  Future<String> getBoardPreviewQuality() async => boardPreviewQuality;

  @override
  Future<void> setBoardPreviewQuality(String quality) async {
    boardPreviewQuality = quality;
  }

  @override
  Future<bool> getBoardPreviewCompressionEnabled() async =>
      boardPreviewCompressionEnabled;

  @override
  Future<void> setBoardPreviewCompressionEnabled(bool enabled) async {
    boardPreviewCompressionEnabled = enabled;
  }

  @override
  Future<bool> getPushNotificationsEnabled() async => pushNotificationsEnabled;

  @override
  Future<void> setPushNotificationsEnabled(bool value) async {
    pushNotificationsEnabled = value;
  }

  @override
  Future<bool> getInviteAlertsEnabled() async => inviteAlertsEnabled;

  @override
  Future<void> setInviteAlertsEnabled(bool value) async {
    inviteAlertsEnabled = value;
  }

  @override
  Future<bool> getFriendAlertsEnabled() async => friendAlertsEnabled;

  @override
  Future<void> setFriendAlertsEnabled(bool value) async {
    friendAlertsEnabled = value;
  }

  @override
  Future<void> clearLocalCache() async {}
}

class FakeProfileService implements ProfileService {
  Map<String, dynamic>? userData;
  Map<String, dynamic> lastUpdatedNotifPrefs = {};

  FakeProfileService({this.userData});

  @override
  Future<Map<String, dynamic>?> getCurrentUserData() async => userData;

  @override
  Future<void> updateNotificationPreferences({
    bool? pushNotificationsEnabled,
    bool? inviteAlertsEnabled,
    bool? friendAlertsEnabled,
  }) async {
    if (pushNotificationsEnabled != null) {
      lastUpdatedNotifPrefs['pushNotificationsEnabled'] =
          pushNotificationsEnabled;
    }
    if (inviteAlertsEnabled != null) {
      lastUpdatedNotifPrefs['inviteAlertsEnabled'] = inviteAlertsEnabled;
    }
    if (friendAlertsEnabled != null) {
      lastUpdatedNotifPrefs['friendAlertsEnabled'] = friendAlertsEnabled;
    }
  }

  @override
  Future<ProfileViewData> loadProfile(String userId) =>
      throw UnimplementedError();

  @override
  Future<String?> saveProfileChanges({
    required String name,
    required String bio,
    String? imageData,
    String? filename,
  }) => throw UnimplementedError();

  @override
  Future<void> updatePrivacySettings({
    required bool isProfilePublic,
    required bool showOnlineStatus,
    required bool showEmail,
  }) => throw UnimplementedError();

  @override
  Future<void> updatePreferredTags(List<String> tags) =>
      throw UnimplementedError();

  @override
  Future<void> updateProfile({required String name, required String bio}) =>
      throw UnimplementedError();

  @override
  Future<String> uploadProfilePhoto({
    required String imageData,
    required String filename,
  }) => throw UnimplementedError();

  @override
  Stream<Map<String, dynamic>?> watchUserById(String userId) =>
      throw UnimplementedError();
}

void main() {
  group('SettingsBloc Notification Preferences', () {
    late FakeSettingsService settingsService;
    late FakeProfileService profileService;

    setUp(() {
      settingsService = FakeSettingsService();
      profileService = FakeProfileService();
    });

    test('initial state has default notification preferences enabled', () {
      final bloc = SettingsBloc(
        settingsService: settingsService,
        profileService: profileService,
      );

      expect(bloc.state.pushNotificationsEnabled, isTrue);
      expect(bloc.state.inviteAlertsEnabled, isTrue);
      expect(bloc.state.friendAlertsEnabled, isTrue);
    });

    test('loads notification preferences from local settings service', () async {
      settingsService.pushNotificationsEnabled = false;
      settingsService.inviteAlertsEnabled = false;
      settingsService.friendAlertsEnabled = true;

      final bloc = SettingsBloc(
        settingsService: settingsService,
        profileService: profileService,
      );

      bloc.add(const SettingsLoadRequested());
      await pumpEventQueue();

      expect(bloc.state.pushNotificationsEnabled, isFalse);
      expect(bloc.state.inviteAlertsEnabled, isFalse);
      expect(bloc.state.friendAlertsEnabled, isTrue);
    });

    test('syncs notification preferences from remote profile if present', () async {
      settingsService.pushNotificationsEnabled = true;
      profileService.userData = {
        'notificationPreferences': {
          'pushNotificationsEnabled': false,
          'inviteAlertsEnabled': false,
          'friendAlertsEnabled': false,
        },
      };

      final bloc = SettingsBloc(
        settingsService: settingsService,
        profileService: profileService,
      );

      bloc.add(const SettingsLoadRequested());
      await pumpEventQueue();

      expect(bloc.state.pushNotificationsEnabled, isFalse);
      expect(bloc.state.inviteAlertsEnabled, isFalse);
      expect(bloc.state.friendAlertsEnabled, isFalse);
      expect(settingsService.pushNotificationsEnabled, isFalse);
      expect(settingsService.inviteAlertsEnabled, isFalse);
      expect(settingsService.friendAlertsEnabled, isFalse);
    });

    test('updates preferences locally and remotely when toggled', () async {
      final bloc = SettingsBloc(
        settingsService: settingsService,
        profileService: profileService,
      );

      bloc.add(
        const SettingsNotificationPreferencesChanged(
          pushNotificationsEnabled: false,
          inviteAlertsEnabled: false,
        ),
      );
      await pumpEventQueue();

      expect(bloc.state.pushNotificationsEnabled, isFalse);
      expect(bloc.state.inviteAlertsEnabled, isFalse);
      expect(bloc.state.friendAlertsEnabled, isTrue);
      expect(settingsService.pushNotificationsEnabled, isFalse);
      expect(settingsService.inviteAlertsEnabled, isFalse);
      expect(
        profileService.lastUpdatedNotifPrefs['pushNotificationsEnabled'],
        isFalse,
      );
      expect(
        profileService.lastUpdatedNotifPrefs['inviteAlertsEnabled'],
        isFalse,
      );
    });
  });
}
