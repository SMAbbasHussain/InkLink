import '../../models/board.dart';

/// Shared board domain validation, normalization, and document-shape rules.
///
/// Pure Dart (no Flutter or Firebase imports) so mobile and web repositories
/// and domain services apply identical constraints and write identical
/// Firestore document shapes.

/// The canvas engine every board document records.
const String boardEngine = 'crdt_v1';

/// Maximum tags per board.
const int maxBoardTags = 5;

/// Maximum board title length.
const int maxBoardNameLength = 80;

/// Trimmed title, or "Untitled Board" when nothing usable is left.
String normalizeBoardName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Untitled Board';
  return trimmed.length > maxBoardNameLength
      ? trimmed.substring(0, maxBoardNameLength)
      : trimmed;
}

/// `null` when the title is acceptable, otherwise the user-facing error.
String? validateBoardName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Please enter a board name.';
  if (trimmed.length > maxBoardNameLength) {
    return 'Board name must be $maxBoardNameLength characters or less.';
  }
  return null;
}

/// Tags normalized as trimmed, lower-cased, deduplicated, capped at
/// [maxBoardTags].
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

/// Whether a join code allows joining the board directly.
bool boardJoinViaCodeEnabled({
  required String visibility,
  required String privateJoinPolicy,
}) =>
    normalizeVisibility(visibility) == Board.visibilityPublic ||
    normalizePrivateJoinPolicy(privateJoinPolicy) == Board.policyLinkCanJoin;

/// Document fields for a newly created board (timestamps added by data layer).
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

/// Document fields for a duplicated board owned by [uid].
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

/// Board settings payload written to Firestore (`invitePolicy` stays nested).
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
