/// Formats [time] as a 24-hour `HH:mm` clock label.
///
/// Shared by the board chat drawer and the chat message bubble, which each
/// carried an identical private copy of this formatting before.
String formatClockTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Formats an epoch-millisecond timestamp as a 24-hour `HH:mm` clock label.
String formatClockTimeFromMillis(int millisecondsSinceEpoch) =>
    formatClockTime(DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch));
