// Coercions for loosely typed payloads (Firestore maps, model deserializers).
//
// These fall back exactly as the model and repository copies did, so moving a
// value from one reader to another cannot change the result.

/// Reads a date from a payload value.
///
/// Missing, unparsable and unreadable values all fall back to "now", which is
/// what every deserializer in the app expects for a timestamp it cannot read.
DateTime parseDateTimeValue(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  try {
    return (value as dynamic).toDate() as DateTime? ?? DateTime.now();
  } catch (_) {
    return DateTime.now();
  }
}

/// Reads an integer count from a payload value, defaulting to `0`.
int parseIntValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
