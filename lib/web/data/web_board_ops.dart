import '../../domain/models/board.dart';
import '../../domain/models/notification/in_app_notification.dart';

// Pure helpers for the web companion's board lifecycle and notification feed.
//
// Everything here mirrors what the mobile repositories write, so a board
// created, renamed, copied or re-configured in a browser is the same document
// the phone reads. Keeping the document shapes here (instead of inside the
// Firestore repository) means they can be unit tested without a network.

/// The canvas engine every board document records (same as the phone).
const String boardEngine = 'crdt_v1';

/// A board carries at most five tags, like the phone's editor.
const int maxBoardTags = 5;

/// Board titles are capped by the phone's rename dialog.
const int maxBoardNameLength = 80;

/// Trimmed title, or "Untitled Board" when nothing usable is left.
String normalizeBoardName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Untitled Board';
  return trimmed.length > maxBoardNameLength
      ? trimmed.substring(0, maxBoardNameLength)
      : trimmed;
}

/// `null` when the title is acceptable, otherwise the message to show.
String? validateBoardName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Please enter a board name.';
  if (trimmed.length > maxBoardNameLength) {
    return 'Board name must be $maxBoardNameLength characters or less.';
  }
  return null;
}

/// Tags as the phone stores them: trimmed, lower-cased, de-duplicated and
/// limited to [maxBoardTags].
List<String> normalizeBoardTags(Iterable<String> tags) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in tags) {
    final tag = raw.trim().toLowerCase();
    if (tag.isEmpty || !seen.add(tag)) continue;
    out.add(tag);
    if (out.length == maxBoardTags) break;
  }
  return List<String>.unmodifiable(out);
}

String normalizeVisibility(String visibility) =>
    visibility == Board.visibilityPublic
    ? Board.visibilityPublic
    : Board.visibilityPrivate;

String normalizePrivateJoinPolicy(String policy) =>
    policy == Board.policyLinkCanJoin
    ? Board.policyLinkCanJoin
    : Board.policyOwnerOnlyInvite;

String normalizeWhoCanInvite(String who) => switch (who) {
  Board.inviteOwnerEditor => Board.inviteOwnerEditor,
  Board.inviteAllMembers => Board.inviteAllMembers,
  _ => Board.inviteOwnerOnly,
};

String normalizeLinkJoinRole(String role) =>
    role == Board.roleEditor ? Board.roleEditor : Board.roleViewer;

/// Whether a join code lets someone into the board (the phone derives this
/// from visibility and the private-board policy).
bool boardJoinViaCodeEnabled({
  required String visibility,
  required String privateJoinPolicy,
}) =>
    normalizeVisibility(visibility) == Board.visibilityPublic ||
    normalizePrivateJoinPolicy(privateJoinPolicy) == Board.policyLinkCanJoin;

/// The board document (and member index rows) fields the phone writes when it
/// creates a board from `CreateBoardScreen`. Timestamps are added by the
/// caller because a Firestore `FieldValue` cannot be built here.
Map<String, dynamic> newBoardFields({
  required String boardId,
  required String uid,
  required String name,
  required String visibility,
  required String privateJoinPolicy,
  required String whoCanInvite,
  required String defaultLinkJoinRole,
  required List<String> tags,
  bool allowMembersToCopy = false,
}) {
  final normalizedVisibility = normalizeVisibility(visibility);
  final normalizedPolicy = normalizePrivateJoinPolicy(privateJoinPolicy);
  return <String, dynamic>{
    'boardId': boardId,
    'title': normalizeBoardName(name),
    'name': normalizeBoardName(name),
    'ownerId': uid,
    'members': <String>[uid],
    'memberCount': 1,
    'membersCount': 1,
    'engine': boardEngine,
    'visibility': normalizedVisibility,
    'privateJoinPolicy': normalizedPolicy,
    'tags': normalizeBoardTags(tags),
    'joinViaCodeEnabled': boardJoinViaCodeEnabled(
      visibility: normalizedVisibility,
      privateJoinPolicy: normalizedPolicy,
    ),
    'joinCode': boardId,
    'isArchived': false,
    'isPaused': false,
    'allowMembersToCopy': allowMembersToCopy,
    'invitePolicy': <String, dynamic>{
      'whoCanInvite': normalizeWhoCanInvite(whoCanInvite),
      'defaultLinkJoinRole': normalizeLinkJoinRole(defaultLinkJoinRole),
    },
    'lastEditedBy': uid,
  };
}

/// The board document for a copy of [source]: the copy is a standalone board
/// owned by [uid], so membership, previews, workspaces and pending invites are
/// reset exactly as the phone's duplicate does.
Map<String, dynamic> duplicatedBoardFields(
  Map<String, dynamic> source, {
  required String newBoardId,
  required String uid,
  String? customTitle,
}) {
  final originalTitle =
      (source['title'] as String?) ?? (source['name'] as String?) ?? 'Board';
  final title = customTitle?.trim().isNotEmpty == true
      ? customTitle!.trim()
      : '$originalTitle (Copy)';
  final data = Map<String, dynamic>.from(source)
    ..['boardId'] = newBoardId
    ..['title'] = title
    ..['name'] = title
    ..['ownerId'] = uid
    ..['engine'] = boardEngine
    ..['members'] = <String>[uid]
    ..['memberCount'] = 1
    ..['membersCount'] = 1
    ..['joinCode'] = newBoardId
    ..['isArchived'] = false
    ..['isPaused'] = false
    ..['allowMembersToCopy'] = false
    ..['invitePolicy'] = <String, dynamic>{
      'whoCanInvite': Board.inviteOwnerOnly,
      'defaultLinkJoinRole': Board.roleViewer,
    }
    ..remove('previewPath')
    ..remove('workspaceId')
    ..remove('workspaceIds')
    ..remove('pendingInvites')
    ..remove('invitedUserIds');
  return data;
}

/// The fields the board settings page (and the phone's blob) writes. The
/// invite pair lives in a nested `invitePolicy` map; flat keys would be
/// ignored by the shared model and reverted on the next snapshot.
Map<String, dynamic> boardSettingsFields({
  required String visibility,
  required String privateJoinPolicy,
  required String whoCanInvite,
  required String defaultLinkJoinRole,
  bool? allowMembersToCopy,
}) {
  final normalizedVisibility = normalizeVisibility(visibility);
  final normalizedPolicy = normalizePrivateJoinPolicy(privateJoinPolicy);
  return <String, dynamic>{
    'visibility': normalizedVisibility,
    'privateJoinPolicy': normalizedPolicy,
    'joinViaCodeEnabled': boardJoinViaCodeEnabled(
      visibility: normalizedVisibility,
      privateJoinPolicy: normalizedPolicy,
    ),
    'invitePolicy': <String, dynamic>{
      'whoCanInvite': normalizeWhoCanInvite(whoCanInvite),
      'defaultLinkJoinRole': normalizeLinkJoinRole(defaultLinkJoinRole),
    },
    if (allowMembersToCopy != null) 'allowMembersToCopy': allowMembersToCopy,
  };
}

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
