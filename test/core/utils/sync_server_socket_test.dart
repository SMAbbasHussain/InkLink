import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/sync_server_socket.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// The board sync and the board chat each open a socket to the same sync
/// server. They must not get the same Socket object: replacing one
/// (`dispose()` clears all listeners) would remove the other's handlers,
/// which is how live board updates stopped after a reconnect.
/// Nothing here connects (auto-connect is off).
void main() {
  // Same shape as the real address: a host and no path.
  const url = 'https://sync.example.test';

  io.OptionBuilder options() => io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': 't'})
      .disableAutoConnect();

  test('without forceNew the library hands out one shared socket', () {
    // Documents the library behaviour the helper guards against.
    final a = io.io(url, options().build());
    final b = io.io(url, options().build());
    addTearDown(() {
      a.dispose();
      b.dispose();
    });
    expect(identical(a, b), isTrue);
  });

  test('each caller gets its own socket and connection', () {
    final sync = openSyncServerSocket(url, options().enableReconnection());
    final chat = openSyncServerSocket(url, options().disableReconnection());
    addTearDown(() {
      sync.dispose();
      chat.dispose();
    });
    expect(identical(sync, chat), isFalse);
    expect(identical(sync.io, chat.io), isFalse);

    // Disposing one leaves the other's listeners in place.
    var connects = 0;
    sync.onConnect((_) => connects++);
    chat.dispose();
    sync.emitReserved('connect');
    expect(connects, 1);
  });
}
