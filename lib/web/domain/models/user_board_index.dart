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

/// Boards of a workspace the user can open, in link order. Mirrors the
/// phone: links marked `visible: false` are hidden, and a board shows only
/// if it is in the user's own board index ([readable]).
List<String> visibleWorkspaceBoardIds(
  Iterable<MapEntry<String, Map<String, dynamic>>> links,
  Set<String> readable,
) {
  final ids = <String>[];
  for (final link in links) {
    final data = link.value;
    if (data.containsKey('visible') && data['visible'] != true) continue;
    final boardId = (data['boardId'] as String?) ?? link.key;
    if (boardId.isNotEmpty && readable.contains(boardId)) ids.add(boardId);
  }
  return ids;
}
