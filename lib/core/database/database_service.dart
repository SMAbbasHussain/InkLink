import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'collections/local_board.dart';
import 'collections/local_crdt_update.dart';
import '../../domain/models/user_model.dart';

class DatabaseService {
  late Future<Isar> db;

  DatabaseService() {
    db = _initDb();
  }

  Future<Isar> _initDb() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [LocalBoardSchema, LocalCrdtUpdateSchema, UserModelSchema],
        directory: dir.path,
        inspector: true,
      );
    }
    return Future.value(Isar.getInstance());
  }

  Future<Isar> get database async => await db;

  Future<void> clearLocalCache() async {
    final isar = await database;
    await isar.writeTxn(() async {
      await isar.localBoards.clear();
      await isar.localCrdtUpdates.clear();
      await isar.userModels.clear();
    });
  }
}
