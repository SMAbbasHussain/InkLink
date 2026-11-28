import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/notification_preferences.dart';
import '../../../domain/models/friends/friend.dart';
import '../../../domain/models/friends/friend_request.dart';
import '../../../domain/models/invitation/board_invitation.dart';
import '../../../domain/models/notification/in_app_notification.dart';
import '../../../domain/models/workspace.dart';
import '../../../domain/repositories/notification/notification_repository.dart';
import '../../core/web_stream_utils.dart';
import '../models/web_notification_rules.dart';

/// Firestore and browser-preferences data source for invites, friends,
/// blocked users, and notifications on the web companion.
class WebSocialDataSource {
  final AuthService _auth;
  final FirestoreService _firestore;
  final NotificationRepository _notificationRepository;

  NotificationPreferences? _notificationPrefs;
  Set<String>? _cachedReadIds;
  final _readIdsController = StreamController<Set<String>>.broadcast();

  WebSocialDataSource({
    required AuthService authService,
    required FirestoreService firestoreService,
    required this._notificationRepository,
  }) : _auth = authService,
       _firestore = firestoreService;

  String? get _uid => _auth.getCurrentUserId();

  Future<NotificationPreferences> _readPrefs() async => _notificationPrefs ??=
      NotificationPreferences(prefs: await SharedPreferences.getInstance());

  void _emitReadIds(Set<String> ids) {
    _cachedReadIds = ids;
    if (!_readIdsController.isClosed) _readIdsController.add(ids);
  }

  // ── Invites ─────────────────────────────────────────────────────────────

  Stream<List<BoardInvitation>> watchBoardInvites() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.boardInvites)
        .where(FirestorePaths.toUid, isEqualTo: uid)
        .where(FirestorePaths.status, isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) =>
              s.docs
                  .map((d) => BoardInvitation.fromMap(d.data(), d.id))
                  .where(
                    (i) =>
                        i.expiresAt == null ||
                        i.expiresAt!.isAfter(DateTime.now()),
                  )
                  .toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
        );
  }

  Stream<List<WorkspaceInvite>> watchWorkspaceInvites() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.workspaceInvites)
        .where(FirestorePaths.toUid, isEqualTo: uid)
        .where(FirestorePaths.status, isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
            final data = d.data();
            return WorkspaceInvite(
              id: d.id,
              workspaceId: (data[FirestorePaths.workspaceId] as String?) ?? '',
              fromUid: (data[FirestorePaths.fromUid] as String?) ?? '',
              toUid: (data[FirestorePaths.toUid] as String?) ?? '',
              senderName:
                  (data[FirestorePaths.senderName] as String?) ??
                  (data[FirestorePaths.fromUid] as String?) ??
                  'InkLink User',
              senderPhotoUrl: data[FirestorePaths.senderPic] as String?,
              workspaceName:
                  (data[FirestorePaths.name] as String?) ?? 'Workspace',
              status: (data[FirestorePaths.status] as String?) ?? 'pending',
              timestamp:
                  (data[FirestorePaths.timestamp] as Timestamp?)?.toDate() ??
                  DateTime.now(),
            );
          }).toList(),
        );
  }

  // ── Friends & Blocks ────────────────────────────────────────────────────

  Stream<List<FriendRequest>> watchIncomingFriendRequests() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.friendRequests)
        .where(FirestorePaths.toUid, isEqualTo: uid)
        .where(FirestorePaths.status, isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => FriendRequest.fromMap(d.data(), d.id)).toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
        );
  }

  Stream<List<Friend>> watchFriends() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.friendsSubcollection)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = snapshot.docs
              .map((d) => d.id)
              .where((id) => id.isNotEmpty && id != uid)
              .toList();
          final friends = <Friend>[];
          for (final batch in chunked(ids)) {
            final users = await _firestore
                .collection(FirestorePaths.users)
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            for (final doc in users.docs) {
              friends.add(Friend.fromMap(doc.data(), doc.id));
            }
          }
          friends.sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
          return friends;
        });
  }

  Future<List<Friend>> searchUsersByEmail(String email) async {
    final query = email.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final snap = await _firestore
        .collection(FirestorePaths.users)
        .where(FirestorePaths.email, isEqualTo: query)
        .limit(5)
        .get();
    final uid = _uid;
    return [
      for (final doc in snap.docs)
        if (doc.id != uid) Friend.fromMap(doc.data(), doc.id),
    ];
  }

  Stream<List<Friend>> watchBlockedUsers() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.blockedUsers)
        .where('blockerUid', isEqualTo: uid)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = [
            for (final doc in snapshot.docs)
              (doc.data()['blockedUid'] as String?)?.trim() ?? '',
          ].where((id) => id.isNotEmpty).toList();
          final friends = <Friend>[];
          for (final batch in chunked(ids)) {
            final users = await _firestore
                .collection(FirestorePaths.users)
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            for (final doc in users.docs) {
              friends.add(Friend.fromMap(doc.data(), doc.id));
            }
          }
          for (final id in ids) {
            if (!friends.any((f) => f.uid == id)) {
              friends.add(Friend(uid: id, displayName: id));
            }
          }
          friends.sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
          return friends;
        });
  }

  // ── Notifications & Browser Read State ──────────────────────────────────

  Stream<List<InAppNotification>> watchNotifications() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.notificationsSubcollection)
        .orderBy(FirestorePaths.timestamp, descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) => s.docs
              .where((d) => isFeedNotification(d.data()))
              .map(
                (d) => InAppNotification.fromMap(
                  withNotificationSenderFields(d.data()),
                  d.id,
                ),
              )
              .toList(),
        );
  }

  Future<void> deleteNotification(String notificationId) =>
      _notificationRepository.deleteNotification(notificationId);

  Stream<Set<String>> watchReadNotificationIds() async* {
    final uid = _uid;
    if (uid == null) {
      yield const <String>{};
      return;
    }
    final prefs = await _readPrefs();
    _cachedReadIds = await prefs.getReadNotificationIds(uid);
    yield _cachedReadIds!;
    yield* _readIdsController.stream;
  }

  Future<void> markNotificationRead(String id) async {
    final uid = _uid;
    if (uid == null || id.isEmpty) return;
    final prefs = await _readPrefs();
    await prefs.markAsRead(id, uid);
    final current = _cachedReadIds ?? await prefs.getReadNotificationIds(uid);
    _emitReadIds({...current, id});
  }

  Future<void> markAllNotificationsRead(Iterable<String> ids) async {
    final uid = _uid;
    if (uid == null) return;
    final prefs = await _readPrefs();
    final next = <String>{...?_cachedReadIds};
    for (final id in ids) {
      if (id.isEmpty || next.contains(id)) continue;
      await prefs.markAsRead(id, uid);
      next.add(id);
    }
    _emitReadIds(next);
  }
}
