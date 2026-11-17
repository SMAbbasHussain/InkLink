// Pure helpers for the InkLink web companion (no Firebase, easy to test).
//
// The companion is a separate, web-only entry point (lib/web/main_web.dart).
// It never imports the mobile app's Isar database or screens, so the phone
// app is unaffected by anything in lib/web/.

/// Board ids the user owns or joined, read from `users/{uid}/boards`.
class UserBoardIndex {
  final Set<String> owned;
  final Set<String> joined;

  const UserBoardIndex({required this.owned, required this.joined});

  Set<String> get all => {...owned, ...joined};

  /// Mirrors the mobile dashboard: `boardId` (or the doc id) and
  /// `relation` ('owned' or anything else = joined).
  factory UserBoardIndex.fromDocs(
    Iterable<MapEntry<String, Map<String, dynamic>>> docs,
  ) {
    final owned = <String>{};
    final joined = <String>{};
    for (final doc in docs) {
      final boardId = (doc.value['boardId'] as String?)?.trim();
      final id = (boardId == null || boardId.isEmpty) ? doc.key : boardId;
      if (id.isEmpty) continue;
      if (doc.value['relation'] == 'owned') {
        owned.add(id);
      } else {
        joined.add(id);
      }
    }
    joined.removeAll(owned);
    return UserBoardIndex(owned: owned, joined: joined);
  }
}

/// Splits [ids] into chunks small enough for a Firestore `whereIn` query.
List<List<T>> chunked<T>(List<T> ids, [int size = 10]) {
  if (size <= 0) throw ArgumentError.value(size, 'size');
  return [
    for (var i = 0; i < ids.length; i += size)
      ids.sublist(i, i + size > ids.length ? ids.length : i + size),
  ];
}

/// Link that opens a board in the InkLink phone app (an allow-listed deep link).
String boardAppLink(String boardId) => 'https://inklink.app/board/$boardId';

/// Custom-scheme link that opens the board directly in the installed app.
String boardSchemeLink(String boardId) => 'inklink://board/$boardId';

/// The mobile notification feed hides chat messages; the companion does too.
bool isFeedNotification(Map<String, dynamic> data) =>
    data['type'] != 'chat_message';

/// Cloud Functions save a notification's sender as `fromUid` / `senderName` /
/// `senderPic`, but the shared `InAppNotification.fromMap` reads
/// `senderUid` / `senderDisplayName` / `senderPhotoUrl`. Fill the latter from
/// the former (without overwriting) so the web shows who sent it. The shared
/// model is left unchanged.
Map<String, dynamic> withNotificationSenderFields(Map<String, dynamic> data) {
  final out = Map<String, dynamic>.from(data);
  out['senderUid'] ??= data['fromUid'];
  out['senderDisplayName'] ??= data['senderName'];
  out['senderPhotoUrl'] ??= data['senderPic'];
  return out;
}

/// Initials for an avatar, e.g. "Fahad Basraa" -> "FB".
String initialsOf(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// Label shown on a board card: "Owner", "Member" or "Public".
///
/// [knownMember] is true for the user's own board list (every board there is
/// owned or joined). For public boards, membership comes from `members`.
String boardRoleLabel({
  required String ownerId,
  required List<String> memberIds,
  required String? currentUid,
  bool knownMember = false,
}) {
  if (currentUid != null && ownerId == currentUid) return 'Owner';
  if (knownMember || (currentUid != null && memberIds.contains(currentUid))) {
    return 'Member';
  }
  return 'Public';
}

/// What a notification avatar shows when the sender's name is missing.
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

/// Validation for the profile form, matching the mobile limits loosely.
String? validateDisplayName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Please enter your name.';
  if (trimmed.length > 50) return 'Name must be 50 characters or less.';
  return null;
}

String? validateBio(String value) {
  if (value.trim().length > 160) return 'Bio must be 160 characters or less.';
  return null;
}

/// Short relative time like "5m ago" for lists.
String timeAgo(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.isNegative || diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}
