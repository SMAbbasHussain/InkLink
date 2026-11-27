/// The CRDT update record used by the canvas, its service and the sync
/// repository.
///
/// On phones (and in tests) this is the Isar collection `LocalCrdtUpdate`,
/// unchanged. On the web, where Isar can't compile, it's a plain class with
/// the same name and fields.
library;

export '../../../core/database/collections/local_crdt_update.dart'
    if (dart.library.js_interop) 'local_crdt_update_web.dart';
