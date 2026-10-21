import '../../repositories/settings/settings_repository.dart';

abstract class SettingsService {
  Future<bool> getShowTrayTips();
  Future<void> setShowTrayTips(bool value);
  Future<String> getBoardPreviewQuality();
  Future<void> setBoardPreviewQuality(String quality);
  Future<bool> getBoardPreviewCompressionEnabled();
  Future<void> setBoardPreviewCompressionEnabled(bool enabled);
  Future<bool> getPushNotificationsEnabled([String? userId]);
  Future<void> setPushNotificationsEnabled(bool value, [String? userId]);
  Future<bool> getInviteAlertsEnabled([String? userId]);
  Future<void> setInviteAlertsEnabled(bool value, [String? userId]);
  Future<bool> getFriendAlertsEnabled([String? userId]);
  Future<void> setFriendAlertsEnabled(bool value, [String? userId]);
  Future<void> clearLocalCache();
}

class SettingsServiceImpl implements SettingsService {
  final SettingsRepository _settingsRepository;

  SettingsServiceImpl({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  @override
  Future<bool> getShowTrayTips() => _settingsRepository.getShowTrayTips();

  @override
  Future<void> setShowTrayTips(bool value) {
    return _settingsRepository.setShowTrayTips(value);
  }

  @override
  Future<String> getBoardPreviewQuality() {
    return _settingsRepository.getBoardPreviewQuality();
  }

  @override
  Future<void> setBoardPreviewQuality(String quality) {
    return _settingsRepository.setBoardPreviewQuality(quality);
  }

  @override
  Future<bool> getBoardPreviewCompressionEnabled() {
    return _settingsRepository.getBoardPreviewCompressionEnabled();
  }

  @override
  Future<void> setBoardPreviewCompressionEnabled(bool enabled) {
    return _settingsRepository.setBoardPreviewCompressionEnabled(enabled);
  }

  @override
  Future<bool> getPushNotificationsEnabled([String? userId]) {
    return _settingsRepository.getPushNotificationsEnabled(userId);
  }

  @override
  Future<void> setPushNotificationsEnabled(bool value, [String? userId]) {
    return _settingsRepository.setPushNotificationsEnabled(value, userId);
  }

  @override
  Future<bool> getInviteAlertsEnabled([String? userId]) {
    return _settingsRepository.getInviteAlertsEnabled(userId);
  }

  @override
  Future<void> setInviteAlertsEnabled(bool value, [String? userId]) {
    return _settingsRepository.setInviteAlertsEnabled(value, userId);
  }

  @override
  Future<bool> getFriendAlertsEnabled([String? userId]) {
    return _settingsRepository.getFriendAlertsEnabled(userId);
  }

  @override
  Future<void> setFriendAlertsEnabled(bool value, [String? userId]) {
    return _settingsRepository.setFriendAlertsEnabled(value, userId);
  }

  @override
  Future<void> clearLocalCache() => _settingsRepository.clearLocalCache();
}
