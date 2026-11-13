/// Decides what the Android back gesture should do while the shell is on
/// screen: leave the current tab, or exit only after a second press inside
/// [exitWindow].
class BackExitPolicy {
  BackExitPolicy({this.exitWindow = const Duration(seconds: 5)});

  static const String exitHint = 'Press back again to exit';

  final Duration exitWindow;
  DateTime? _lastPressAt;

  /// Returns true when the app should close now.
  bool shouldExit(DateTime now) {
    final lastPress = _lastPressAt;
    _lastPressAt = now;
    if (lastPress == null) return false;
    return now.difference(lastPress) <= exitWindow;
  }

  void reset() {
    _lastPressAt = null;
  }
}
