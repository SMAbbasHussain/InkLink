import 'package:isar_community/isar.dart';

part 'local_board.g.dart';

@collection
class LocalBoard {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String boardId;

  late String title;
  late String ownerId;
  late List<String> members;
  late String engine;
  String? previewPath;
  late DateTime createdAt;
  late DateTime updatedAt;

  // Whether this is synced with Firebase yet
  bool isSynced = true;
}
