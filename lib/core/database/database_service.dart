import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'collections/local_board.dart';
import 'collections/local_operation.dart';

class DatabaseService {
  late Future<Isar> db;

  DatabaseService() {
    db = _initDb();
  }

  Future<Isar> _initDb() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [LocalBoardSchema, LocalOperationSchema],
        directory: dir.path,
        inspector: true,
      );
    }
    return Future.value(Isar.getInstance());
  }

  Future<Isar> get database async => await db;
}
