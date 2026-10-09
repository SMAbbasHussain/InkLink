/// Deterministic tilt angle (in radians) derived from an item's id, so a
/// card's tilt never changes between rebuilds.
double inkDeterministicTilt(String id, {double maxDegrees = 2.5}) {
  if (id.isEmpty) return 0;
  final hash = id.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
  final normalized = (hash % 1000) / 1000; // 0..1
  final degrees = (normalized * 2 - 1) * maxDegrees; // -max..max
  return degrees * 3.1415926535 / 180;
}
