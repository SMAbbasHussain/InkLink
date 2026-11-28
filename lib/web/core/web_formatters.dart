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

/// "Good morning" / "Good afternoon" / "Good evening" for the local hour.
String greetingFor(DateTime time) {
  final h = time.hour;
  if (h >= 5 && h < 12) return 'Good morning';
  if (h >= 12 && h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// First word of a display name, or null when there is no usable name.
String? firstNameOf(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+'));
  final first = parts.isEmpty ? '' : parts.first;
  return first.isEmpty ? null : first;
}

/// The most used tags across boards (most frequent first, then A–Z).
List<String> topTags(Iterable<List<String>> tagLists, {int limit = 8}) {
  final counts = <String, int>{};
  for (final tags in tagLists) {
    for (final t in tags) {
      final tag = t.trim();
      if (tag.isEmpty) continue;
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  final sorted = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return sorted.take(limit).toList();
}

/// "Mar 2025" style date for "Member since".
String memberSince(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
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
