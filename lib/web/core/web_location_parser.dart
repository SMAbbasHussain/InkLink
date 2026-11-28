/// A section of the companion that a browser URL can address, plus the board
/// a deep link points at.
///
/// Kept free of Flutter widgets so the parsing can be unit tested; the app
/// maps the section name onto `WebSection`.
class WebLocation {
  /// Sidebar section name (`boards`, `discover`, …), or null when the URL
  /// does not name one (the app then keeps its default section).
  final String? sectionName;

  /// Board id from `/board/<id>`, if the URL is a board deep link.
  final String? boardId;

  const WebLocation({this.sectionName, this.boardId});

  @override
  String toString() => 'WebLocation($sectionName, board: $boardId)';
}

/// Every section the companion can be linked to (the `WebSection` names).
const Set<String> webSections = {
  'boards',
  'workspaces',
  'discover',
  'invites',
  'friends',
  'notifications',
  'profile',
  'settings',
};

/// Reads a browser path (or hash fragment) into a [WebLocation].
///
/// Accepts `/board/<id>`, `#/board/<id>`, `/discover`, `/discover/`,
/// `#/friends?tab=all` and the empty root path.
WebLocation parseWebLocation(String? rawPath) {
  var path = (rawPath ?? '').trim();
  if (path.isEmpty) return const WebLocation();
  final hash = path.indexOf('#');
  if (hash >= 0) path = path.substring(hash + 1);
  final query = path.indexOf('?');
  if (query >= 0) path = path.substring(0, query);
  final scheme = path.indexOf('://');
  if (scheme >= 0) path = path.substring(scheme + 3);
  if (!path.startsWith('/')) path = '/$path';
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return const WebLocation();

  final head = segments.first.toLowerCase();
  if (head == 'board') {
    final rawId = segments.length > 1 ? segments[1].trim() : '';
    final boardId = rawId.isEmpty ? '' : Uri.decodeComponent(rawId);
    return WebLocation(
      sectionName: 'boards',
      boardId: boardId.isEmpty ? null : boardId,
    );
  }
  return webSections.contains(head)
      ? WebLocation(sectionName: head)
      : const WebLocation();
}
