import 'dart:async';

import 'package:rxdart/rxdart.dart';

/// Singleton registry to deduplicate named streams across callers.
///
/// Uses [share()] instead of [asBroadcastStream] so that the underlying
/// source (e.g. a Firestore listener) is automatically re‑subscribed
/// when the last listener leaves and a new one arrives later.
class StreamRegistry {
  StreamRegistry._();
  static final StreamRegistry instance = StreamRegistry._();

  final Map<String, Stream<dynamic>> _streams = {};

  Stream<T> getOrCreate<T>(String key, Stream<T> Function() create) {
    final existing = _streams[key];
    if (existing != null) {
      return existing as Stream<T>;
    }

    final stream = create().share();
    _streams[key] = stream;
    return stream;
  }

  bool has(String key) => _streams.containsKey(key);

  void remove(String key) {
    _streams.remove(key);
  }

  void clearAll() {
    _streams.clear();
  }
}
