import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/database/collections/local_chat_conversation.dart';
import 'package:inklink/core/database/collections/local_chat_message.dart';
import 'package:inklink/core/database/collections/local_profile.dart';
import 'package:inklink/core/database/local_database_service.dart';
import 'package:inklink/domain/models/chat/chat_message_model.dart';
import 'package:inklink/domain/repositories/chat/chat_repository.dart';
import 'package:inklink/domain/repositories/chat/chat_repository_impl.dart';
import 'package:isar_community/isar.dart';

class _TestLocalDatabaseService implements LocalDatabaseService {
  final Isar _isar;

  _TestLocalDatabaseService(this._isar);

  @override
  Future<Isar> get db => Future.value(_isar);

  @override
  set db(Future<Isar> value) {}

  @override
  Future<Isar> get database => Future.value(_isar);

  @override
  Future<void> clearLocalCache({bool clearChats = false}) async {
    await _isar.writeTxn(() async {
      await _isar.localProfiles.clear();
      if (clearChats) {
        await _isar.localChatConversations.clear();
        await _isar.localChatMessages.clear();
      }
    });
  }
}

String? _resolveBundledIsarLibraryPath() {
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
    if (Platform.isWindows) {
      final dll = File('${rootDir.path}${Platform.pathSeparator}windows${Platform.pathSeparator}libisar.dll');
      if (dll.existsSync()) return dll.path;
    } else if (Platform.isLinux) {
      final so = File('${rootDir.path}${Platform.pathSeparator}linux${Platform.pathSeparator}libisar.so');
      if (so.existsSync()) return so.path;
    } else if (Platform.isMacOS) {
      final dylib = File('${rootDir.path}${Platform.pathSeparator}macos${Platform.pathSeparator}libisar.dylib');
      if (dylib.existsSync()) return dylib.path;
    }
  } catch (_) {}
  return null;
}

void main() {
  final isarLibPath = _resolveBundledIsarLibraryPath();

  group(
    'ChatRepositoryImpl (Isar integration)',
    skip: isarLibPath == null
        ? 'Native Isar library not found in pub cache on this host'
        : false,
    () {
      late Directory tempDir;
      late Isar isar;
      late ChatRepositoryImpl repo;
      var instanceCounter = 0;

      setUpAll(() async {
        await Isar.initializeIsarCore(
          libraries: {Abi.current(): isarLibPath!},
        );
      });

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('inklink_chat_repo_');
        instanceCounter++;
        isar = await Isar.open(
          [
            LocalChatConversationSchema,
            LocalChatMessageSchema,
            LocalProfileSchema,
          ],
          directory: tempDir.path,
          name: 'chat_repo_test_$instanceCounter',
          inspector: false,
        );
        repo = ChatRepositoryImpl(
          localDatabaseService: _TestLocalDatabaseService(isar),
        );
      });

      tearDown(() async {
        await isar.close(deleteFromDisk: true);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test(
        'Comments 2 & 3: colliding sanitized IDs and case-variant Firebase UIDs stay isolated in Isar',
        () async {
          const currentUid = 'User.1';

          await repo.persistMessage(
            currentUid: currentUid,
            model: ChatMessageModel(
              id: 'm-slash',
              conversationId: 'peer/1',
              senderId: 'peer/1',
              senderName: 'Peer Slash',
              type: ChatMessageType.text,
              content: 'Slash message',
              timestamp: DateTime.fromMillisecondsSinceEpoch(1700000001000),
            ),
          );
          await repo.persistMessage(
            currentUid: currentUid,
            model: ChatMessageModel(
              id: 'm-dot',
              conversationId: 'peer.1',
              senderId: 'peer.1',
              senderName: 'Peer Dot',
              type: ChatMessageType.text,
              content: 'Dot message',
              timestamp: DateTime.fromMillisecondsSinceEpoch(1700000002000),
            ),
          );
          await repo.persistMessage(
            currentUid: currentUid,
            model: ChatMessageModel(
              id: 'm-upper',
              conversationId: 'PeerCase',
              senderId: 'PeerCase',
              senderName: 'Upper',
              type: ChatMessageType.text,
              content: 'Upper case peer',
              timestamp: DateTime.fromMillisecondsSinceEpoch(1700000003000),
            ),
          );
          await repo.persistMessage(
            currentUid: currentUid,
            model: ChatMessageModel(
              id: 'm-lower',
              conversationId: 'peercase',
              senderId: 'peercase',
              senderName: 'Lower',
              type: ChatMessageType.text,
              content: 'Lower case peer',
              timestamp: DateTime.fromMillisecondsSinceEpoch(1700000004000),
            ),
          );

          // All 4 distinct peers appear in inbox without collision.
          final convs = await repo.getConversations(currentUid: currentUid);
          expect(
            convs.map((c) => c.id).toSet(),
            {'peer/1', 'peer.1', 'PeerCase', 'peercase'},
          );

          // Each thread returns strictly its own messages.
          expect(
            (await repo.getMessagesForThread(
              currentUid: currentUid,
              conversationId: 'peer/1',
            ))
                .map((m) => m.id),
            ['m-slash'],
          );
          expect(
            (await repo.getMessagesForThread(
              currentUid: currentUid,
              conversationId: 'peer.1',
            ))
                .map((m) => m.id),
            ['m-dot'],
          );
          expect(
            (await repo.getMessagesForThread(
              currentUid: currentUid,
              conversationId: 'PeerCase',
            ))
                .map((m) => m.id),
            ['m-upper'],
          );
          expect(
            (await repo.getMessagesForThread(
              currentUid: currentUid,
              conversationId: 'peercase',
            ))
                .map((m) => m.id),
            ['m-lower'],
          );

          // A colliding signed-in user `user/1` or case-variant `user.1` must
          // see ZERO conversations or messages belonging to `User.1`.
          expect(await repo.getConversations(currentUid: 'user/1'), isEmpty);
          expect(await repo.getConversations(currentUid: 'user.1'), isEmpty);
          expect(
            await repo.getMessagesForThread(
              currentUid: 'user/1',
              conversationId: 'peer/1',
            ),
            isEmpty,
          );

          // Ambiguous Agora username (`peer_1`) refuses to guess between
          // colliding Firebase UIDs (`peer/1` vs `peer.1`).
          final ambiguous = await repo.resolveUniqueUidForAgoraUsername(
            'peer_1',
            currentUid: currentUid,
          );
          expect(ambiguous, 'peer_1');
        },
      );

      test(
        'Comment 4: ingestGroups replaces stale cached memberIds and adminIds and prunes removed groups',
        () async {
          await repo.ingestGroups(
            currentUid: 'me',
            groups: const [
              SyncedGroupInfo(
                groupId: 'g1',
                name: 'Alpha',
                ownerId: 'owner',
                adminIds: ['alice'],
                memberIds: ['owner', 'alice', 'bob', 'me'],
              ),
              SyncedGroupInfo(
                groupId: 'g-removed',
                name: 'Removed Group',
                ownerId: 'owner',
                memberIds: ['owner', 'me'],
              ),
            ],
          );

          // Refresh where `bob` was removed, `alice` lost admin & membership,
          // and `g-removed` is no longer returned by the server.
          await repo.ingestGroups(
            currentUid: 'me',
            pruneMissingServerGroups: true,
            groups: const [
              SyncedGroupInfo(
                groupId: 'g1',
                name: 'Alpha',
                ownerId: 'owner',
                adminIds: [],
                memberIds: ['owner', 'me'],
              ),
            ],
          );

          final convs = await repo.getConversations(currentUid: 'me');
          expect(convs.map((c) => c.id), ['g1']);
          expect(convs.single.adminIds, isEmpty);
          expect(convs.single.memberIds.toSet(), {'owner', 'me'});
        },
      );

      test(
        'Comment 13: ensureDmConversationExists keeps timestamps null and sorts empty chats below active chats',
        () async {
          await repo.ensureDmConversationExists(
            currentUid: 'me',
            peerUid: 'empty-dm',
            name: 'Empty Chat',
          );
          await repo.persistMessage(
            currentUid: 'me',
            model: ChatMessageModel(
              id: 'm1',
              conversationId: 'older-active-dm',
              senderId: 'older-active-dm',
              senderName: 'Active Chat',
              type: ChatMessageType.text,
              content: 'Hello last week',
              timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            ),
          );

          final rawEmpty = await isar.localChatConversations
              .filter()
              .conversationIdEqualTo(
                ChatRepositoryImpl.dmKey('me', 'empty-dm'),
                caseSensitive: true,
              )
              .findFirst();
          expect(rawEmpty, isNotNull);
          expect(rawEmpty!.updatedAt, isNull);
          expect(rawEmpty.lastMessageTimestamp, isNull);

          final convs = await repo.getConversations(currentUid: 'me');
          expect(
            convs.map((c) => c.id).toList(),
            ['older-active-dm', 'empty-dm'],
          );
          expect(convs.last.lastMessageTimestamp, isNull);
        },
      );
    },
  );
}

