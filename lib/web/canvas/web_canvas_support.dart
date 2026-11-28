import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/board_preview_preferences.dart';
import '../../core/utils/canvas_toolbar_preferences.dart';
import '../../core/utils/notification_preferences.dart';
import '../../core/utils/tray_tips_preferences.dart';
import '../../domain/models/canvas/canvas_toolbar_action.dart';
import '../../domain/models/canvas/voice_participant.dart';
import '../../domain/repositories/notification/notification_repository.dart';
import '../../domain/repositories/settings/settings_repository.dart';
import '../../domain/services/voice/voice_service.dart';

/// Browser-stored (`shared_preferences`) toolbar, preview and alert preferences
/// without mobile's Isar cache.
class WebSettingsRepository implements SettingsRepository {
  final Future<SharedPreferences> _prefsFuture;

  WebSettingsRepository(SharedPreferences prefs)
    : _prefsFuture = Future<SharedPreferences>.value(prefs);

  /// Resolves `SharedPreferences` lazily on first access (used by preview/test
  /// composition when a pre-loaded instance was not supplied).
  WebSettingsRepository.lazy() : _prefsFuture = SharedPreferences.getInstance();

  Future<TrayTipsPreferences> _trayTips() async =>
      TrayTipsPreferences(prefs: await _prefsFuture);
  Future<BoardPreviewPreferences> _preview() async =>
      BoardPreviewPreferences(prefs: await _prefsFuture);
  Future<CanvasToolbarPreferences> _toolbar() async =>
      CanvasToolbarPreferences(prefs: await _prefsFuture);
  Future<NotificationPreferences> _notifications() async =>
      NotificationPreferences(prefs: await _prefsFuture);

  @override
  Future<bool> getShowTrayTips() async => (await _trayTips()).getShowTrayTips();

  @override
  Future<void> setShowTrayTips(bool value) async =>
      (await _trayTips()).setShowTrayTips(value);

  @override
  Future<String> getBoardPreviewQuality() async =>
      (await _preview()).getQuality();

  @override
  Future<void> setBoardPreviewQuality(String quality) async =>
      (await _preview()).setQuality(quality);

  @override
  Future<bool> getBoardPreviewCompressionEnabled() async =>
      (await _preview()).getCompressionEnabled();

  @override
  Future<void> setBoardPreviewCompressionEnabled(bool enabled) async =>
      (await _preview()).setCompressionEnabled(enabled);

  @override
  Future<List<CanvasToolbarAction>> getBottomBarActions() async =>
      (await _toolbar()).getBottomBarActions();

  @override
  Future<void> setBottomBarActions(List<CanvasToolbarAction> actions) async =>
      (await _toolbar()).setBottomBarActions(actions);

  @override
  Future<bool> getPushNotificationsEnabled([String? userId]) async =>
      await (await _notifications()).getPushNotificationsEnabled(userId) ??
      true;

  @override
  Future<void> setPushNotificationsEnabled(
    bool value, [
    String? userId,
  ]) async =>
      (await _notifications()).setPushNotificationsEnabled(value, userId);

  @override
  Future<bool> getInviteAlertsEnabled([String? userId]) async =>
      await (await _notifications()).getInviteAlertsEnabled(userId) ?? true;

  @override
  Future<void> setInviteAlertsEnabled(bool value, [String? userId]) async =>
      (await _notifications()).setInviteAlertsEnabled(value, userId);

  @override
  Future<bool> getFriendAlertsEnabled([String? userId]) async =>
      await (await _notifications()).getFriendAlertsEnabled(userId) ?? true;

  @override
  Future<void> setFriendAlertsEnabled(bool value, [String? userId]) async =>
      (await _notifications()).setFriendAlertsEnabled(value, userId);

  @override
  Future<void> clearLocalCache() async {}
}

/// The phone notification feed query, without the Isar copy: the newest
/// 100 notifications, chat messages left out, each map with its `id`.
class WebNotificationRepository implements NotificationRepository {
  final FirestoreService _db;
  final AuthService _authService;

  WebNotificationRepository({
    required this._authService,
    required FirestoreService firestoreService,
  }) : _db = firestoreService;

  CollectionReference<Map<String, dynamic>> _feed(String uid) => _db
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection(FirestorePaths.notificationsSubcollection);

  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() {
    final uid = _authService.getCurrentUserId();
    if (uid == null) return Stream.value(const []);
    return _feed(uid)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              if (doc.data()['type'] != 'chat_message')
                {'id': doc.id, ...doc.data()},
          ],
        );
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    final uid = _authService.getCurrentUserId();
    if (uid == null) return;
    await _feed(uid).doc(notificationId).delete();
  }
}

/// Voice calls are mobile-only for now (Agora RTC needs extra web setup):
/// nobody is ever in a call here, and joining explains where to go.
class WebVoiceService implements VoiceService {
  static const String unavailableMessage =
      'Voice calls are available in the InkLink mobile app.';

  @override
  Stream<List<VoiceParticipant>> watchParticipants(String boardId) =>
      Stream.value(const <VoiceParticipant>[]);

  @override
  Stream<bool> watchIsInCall() => Stream.value(false);

  @override
  Stream<bool> watchIsMuted() => Stream.value(false);

  @override
  bool get isInCall => false;

  @override
  bool get isMuted => false;

  @override
  Stream<bool> watchIsSpeakerOn() => Stream.value(false);

  @override
  bool get isSpeakerOn => false;

  @override
  Future<void> toggleSpeaker() async {}

  @override
  List<VoiceParticipant> get currentParticipants => const [];

  @override
  String? get agoraAppId => null;

  @override
  Future<void> observeBoard(String boardId) async {}

  @override
  Future<void> unobserveBoard(String boardId) async {}

  @override
  Future<void> joinCall(String boardId) async =>
      throw UnsupportedError(unavailableMessage);

  @override
  Future<void> leaveCall(String boardId) async {}

  @override
  Future<void> toggleMute(String boardId) async {}

  @override
  Future<void> setSpeaking({
    required String boardId,
    required bool isSpeaking,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}
}
