import '../../../domain/models/notification/in_app_notification.dart';

/// The notification feed excludes chat messages on both mobile and web.
bool isFeedNotification(Map<String, dynamic> data) =>
    data['type'] != 'chat_message';

/// Cloud Functions save a notification's sender as `fromUid` / `senderName` /
/// `senderPic`, while `InAppNotification.fromMap` reads `senderUid` /
/// `senderDisplayName` / `senderPhotoUrl`. Populate the latter without
/// overwriting existing values.
Map<String, dynamic> withNotificationSenderFields(Map<String, dynamic> data) {
  final out = Map<String, dynamic>.from(data);
  out['senderUid'] ??= data['fromUid'];
  out['senderDisplayName'] ??= data['senderName'];
  out['senderPhotoUrl'] ??= data['senderPic'];
  return out;
}

/// Visual kind for a notification card icon.
enum NotificationKind { invite, friend, mention, access, board, other }

NotificationKind notificationKindOf(String type) {
  if (type.contains('invite')) return NotificationKind.invite;
  if (type.startsWith('friend')) return NotificationKind.friend;
  if (type == 'mention' || type.contains('comment')) {
    return NotificationKind.mention;
  }
  if (type.contains('access') ||
      type.contains('edit_request') ||
      type == 'role_updated' ||
      type == 'member_removed') {
    return NotificationKind.access;
  }
  if (type.startsWith('board') || type.contains('undo')) {
    return NotificationKind.board;
  }
  return NotificationKind.other;
}

/// Notification feed sections, newest first.
enum NotificationGroup { today, thisWeek, earlier }

NotificationGroup notificationGroupOf(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  if (!time.isBefore(today)) return NotificationGroup.today;
  if (time.isAfter(today.subtract(const Duration(days: 7)))) {
    return NotificationGroup.thisWeek;
  }
  return NotificationGroup.earlier;
}

/// Overlays browser-persisted read state onto an [InAppNotification].
InAppNotification withReadState(
  InAppNotification notification,
  Set<String> readIds,
) {
  if (notification.read || !readIds.contains(notification.id)) {
    return notification;
  }
  return InAppNotification(
    id: notification.id,
    uid: notification.uid,
    timestamp: notification.timestamp,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    targetId: notification.targetId,
    senderUid: notification.senderUid,
    senderDisplayName: notification.senderDisplayName,
    senderPhotoUrl: notification.senderPhotoUrl,
    read: true,
    readAt: notification.readAt ?? notification.timestamp,
  );
}

List<InAppNotification> applyReadState(
  List<InAppNotification> notifications,
  Set<String> readIds,
) => [for (final n in notifications) withReadState(n, readIds)];

/// Unread count used by the header badge and the sidebar.
int unreadNotificationCount(
  Iterable<InAppNotification> notifications,
  Set<String> readIds,
) => notifications.where((n) => !withReadState(n, readIds).read).length;

/// Filter chips for the web notifications feed.
enum NotificationFilter { all, requests, boards, friends }

bool notificationMatchesFilter(String type, NotificationFilter filter) {
  switch (filter) {
    case NotificationFilter.all:
      return true;
    case NotificationFilter.requests:
      return type == 'friend_request' ||
          type.contains('access_request') ||
          type == 'join_request' ||
          type == 'edit_request' ||
          type.contains('invite');
    case NotificationFilter.friends:
      return type.startsWith('friend') || type.startsWith('blocked');
    case NotificationFilter.boards:
      if (type.contains('invite')) return false;
      return type.startsWith('board') ||
          type == 'mention' ||
          type.contains('comment') ||
          type == 'role_updated' ||
          type == 'member_removed' ||
          type.contains('undo');
  }
}

/// Where tapping a notification navigates on the web.
enum NotificationTarget { boards, invites, friends, workspace, profile }

NotificationTarget notificationTargetOf(String type) {
  if (type.contains('invite')) {
    return type.contains('workspace')
        ? NotificationTarget.workspace
        : NotificationTarget.invites;
  }
  if (type.startsWith('friend')) return NotificationTarget.friends;
  if (type.contains('profile') || type == 'welcome') {
    return NotificationTarget.profile;
  }
  if (type.contains('workspace')) return NotificationTarget.workspace;
  return NotificationTarget.boards;
}
