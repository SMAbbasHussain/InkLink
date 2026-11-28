import 'dart:async';

/// Splits [ids] into chunks small enough for a Firestore `whereIn` query.
///
/// 30 is the `whereIn` syntax limit. Pass a smaller size for collections
/// whose security rules perform a `get()` per document (boards use
/// `FirestoreBatchFetcher.chunkSize`, 10, for that reason).
List<List<T>> chunked<T>(List<T> ids, [int size = 30]) {
  if (size <= 0) throw ArgumentError.value(size, 'size');
  return [
    for (var i = 0; i < ids.length; i += size)
      ids.sublist(i, i + size > ids.length ? ids.length : i + size),
  ];
}

/// Emits the latest values of [a] and [b] whenever either changes, starting
/// once both have emitted.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A a, B b) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? aSub;
  StreamSubscription<B>? bSub;
  A? aValue;
  B? bValue;
  var aReady = false;
  var bReady = false;
  var done = 0;

  void emit() {
    if (!aReady || !bReady) return;
    try {
      controller.add(combine(aValue as A, bValue as B));
    } catch (error, stack) {
      controller.addError(error, stack);
    }
  }

  void onDone() {
    done++;
    if (done == 2 && !controller.isClosed) controller.close();
  }

  controller = StreamController<R>(
    onListen: () {
      aSub = a.listen(
        (value) {
          aValue = value;
          aReady = true;
          emit();
        },
        onError: controller.addError,
        onDone: onDone,
      );
      bSub = b.listen(
        (value) {
          bValue = value;
          bReady = true;
          emit();
        },
        onError: controller.addError,
        onDone: onDone,
      );
    },
    onPause: () {
      aSub?.pause();
      bSub?.pause();
    },
    onResume: () {
      aSub?.resume();
      bSub?.resume();
    },
    onCancel: () async {
      await aSub?.cancel();
      await bSub?.cancel();
    },
  );
  return controller.stream;
}

/// Link that opens a board in the InkLink phone app (an allow-listed deep link).
String boardAppLink(String boardId) => 'https://inklink.app/board/$boardId';

/// Custom-scheme link that opens the board directly in the installed app.
String boardSchemeLink(String boardId) => 'inklink://board/$boardId';
