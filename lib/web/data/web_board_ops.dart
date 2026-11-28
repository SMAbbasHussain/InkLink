import '../../domain/models/notification/in_app_notification.dart';

export '../../domain/services/board/board_rules.dart';

// Web-specific notification read-state and filtering helpers. Shared board
// normalization, validation, and document-shape rules live in
// `lib/domain/services/board/board_rules.dart` and are re-exported above.

/// Overlays the browser's read state on a notification. The phone keeps read
/// ids in shared_preferences (there is no `read` write to Firestore), so the
/// web feed must do the same or every item looks unread forever.
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

/// The notification feed's filter chips, like the phone's.
enum NotificationFilter { all, requests, boards, friends }

/// Which filter chip a notification belongs to. A notification can match only
/// one chip (All shows everything).
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
      // Invites are requests, even when they name a board.
      if (type.contains('invite')) return false;
      return type.startsWith('board') ||
          type == 'mention' ||
          type.contains('comment') ||
          type == 'role_updated' ||
          type == 'member_removed' ||
          type.contains('undo');
  }
}

/// Where tapping a notification should take the reader on the web.
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
