import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'collections/local_board.dart';
import 'collections/local_blocked_user.dart';
import 'collections/local_crdt_update.dart';
import 'collections/local_friend_request.dart';
import 'collections/local_friend_profile.dart';
import 'collections/local_invitation.dart';
import 'collections/local_non_friend_profile.dart';
import '../../domain/models/user_model.dart';

class LocalDatabaseService {
  late Future<Isar> db;

  LocalDatabaseService() {
    db = _initDb();
  }

  Future<Isar> _initDb() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [
          LocalBoardSchema,
          LocalBlockedUserSchema,
          LocalCrdtUpdateSchema,
          LocalFriendRequestSchema,
          LocalFriendProfileSchema,
          LocalInvitationSchema,
          LocalNonFriendProfileSchema,
          UserModelSchema,
        ],
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
      await isar.localBlockedUsers.clear();
      await isar.localCrdtUpdates.clear();
      await isar.localFriendRequests.clear();
      await isar.localFriendProfiles.clear();
      await isar.localInvitations.clear();
      await isar.localNonFriendProfiles.clear();
      await isar.userModels.clear();
    });
  }
}
