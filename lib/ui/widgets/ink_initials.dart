/// Derives up to two uppercase initials from a display name (or email),
/// e.g. "Fahad Basraa" -> "FB", "ayesha@inklink.app" -> "A".
String inkInitialsFor(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return '?';

  final source = trimmed.contains('@') ? trimmed.split('@').first : trimmed;
  final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
