import 'package:socket_io_client/socket_io_client.dart' as io;

/// Opens a Socket.IO client to the sync server on a connection of its own.
///
/// socket_io_client caches one connection per server and, for an address
/// without a path (like the sync server's), hands every caller the same
/// Socket object. The board sync and the board chat would then share one
/// socket, and when either replaced its socket (`dispose()` clears every
/// listener) the other silently lost its handlers: after a reconnect the
/// board was never rejoined and live updates stopped arriving.
/// `forceNew` gives each caller its own connection.
io.Socket openSyncServerSocket(String url, io.OptionBuilder options) =>
    io.io(url, options.enableForceNew().build());
