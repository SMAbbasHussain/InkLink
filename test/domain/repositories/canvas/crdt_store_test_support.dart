import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:inklink/core/database/collections/local_canvas_sync_state.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/core/database/local_database_service.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/domain/repositories/canvas/crdt_local_store.dart';
import 'package:inklink/domain/repositories/canvas/isar_crdt_local_store.dart';
import 'package:inklink/domain/repositories/canvas/memory_crdt_local_store.dart';
import 'package:isar_community/isar.dart';

/// A store under test plus how to clean it up.
class StoreHandle {
  final CrdtLocalStore store;
  final Future<void> Function() dispose;

  /// The Isar instance behind an Isar store (null for the memory store).
  final Isar? isar;

  StoreHandle(this.store, this.dispose, {this.isar});
}

/// Builds a fresh store for each test.
typedef StoreFactory = Future<StoreHandle> Function();

/// The native Isar library bundled with isar_community_flutter_libs, or null
/// when it isn't on this machine (Isar tests are then skipped).
String? resolveBundledIsarLibraryPath() {
  try {
    final configFile = File('.dart_tool/package_config.json');
    if (!configFile.existsSync()) return null;
    final jsonMap = jsonDecode(configFile.readAsStringSync()) as Map;
    final packages = (jsonMap['packages'] as List).cast<Map>();
    final libsPkg = packages.cast<Map?>().firstWhere(
      (p) => p?['name'] == 'isar_community_flutter_libs',
      orElse: () => null,
    );
    if (libsPkg == null) return null;
    final rootUri = Uri.parse(libsPkg['rootUri'] as String);
    final rootDir = Directory.fromUri(
      rootUri.isAbsolute ? rootUri : configFile.parent.uri.resolveUri(rootUri),
    );
    final sep = Platform.pathSeparator;
    final String name;
    if (Platform.isWindows) {
      name = 'windows${sep}libisar.dll';
    } else if (Platform.isLinux) {
      name = 'linux${sep}libisar.so';
    } else if (Platform.isMacOS) {
      name = 'macos${sep}libisar.dylib';
    } else {
      return null;
    }
    final lib = File('${rootDir.path}$sep$name');
    return lib.existsSync() ? lib.path : null;
  } catch (_) {
    return null;
  }
}

bool _isarCoreReady = false;
int _isarCounter = 0;

Future<StoreHandle> memoryStoreFactory() async =>
    StoreHandle(MemoryCrdtLocalStore(), () async {});

/// An Isar store on a temporary on-disk database with the two collections
/// the canvas sync uses.
Future<StoreHandle> isarStoreFactory(String libraryPath) async {
  if (!_isarCoreReady) {
    await Isar.initializeIsarCore(libraries: {Abi.current(): libraryPath});
    _isarCoreReady = true;
  }
  final dir = await Directory.systemTemp.createTemp('inklink_crdt_store_');
  final isar = await Isar.open(
    [LocalCrdtUpdateSchema, LocalCanvasSyncStateSchema],
    directory: dir.path,
    name: 'crdt_store_test_${_isarCounter++}',
    inspector: false,
  );
  return StoreHandle(
    IsarCrdtLocalStore(TestLocalDatabaseService(isar)),
    () async {
      await isar.close(deleteFromDisk: true);
      if (dir.existsSync()) await dir.delete(recursive: true);
    },
    isar: isar,
  );
}

class TestLocalDatabaseService implements LocalDatabaseService {
  final Isar _isar;

  TestLocalDatabaseService(this._isar);

  @override
  Future<Isar> get db => Future.value(_isar);

  @override
  set db(Future<Isar> value) {}

  @override
  Future<Isar> get database => Future.value(_isar);

  @override
  Future<void> clearLocalCache({bool clearChats = false}) async {}
}

/// Signed-out auth: the sync repository then never opens a socket.
class SignedOutAuthService implements AuthService {
  @override
  String? getCurrentUserId() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used here');
}

LocalCrdtUpdate crdtUpdate(
  String updateId, {
  String boardId = 'board-1',
  String? elementId,
  DateTime? appliedAt,
  int version = 0,
  bool isSynced = false,
  bool isDeleted = false,
  String payloadBase64 = 'AQID',
}) => LocalCrdtUpdate()
  ..updateId = updateId
  ..boardId = boardId
  ..elementId = elementId
  ..action = 'upsert'
  ..payloadBase64 = payloadBase64
  ..sourceClientId = 'client-1'
  ..appliedAt = appliedAt ?? DateTime.utc(2026, 1, 1)
  ..version = version
  ..isSynced = isSynced
  ..isDeleted = isDeleted;
