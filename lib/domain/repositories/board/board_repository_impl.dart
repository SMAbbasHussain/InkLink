import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/collections/local_board.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../models/board.dart';
import 'board_repository.dart';

class FirestoreBoardRepository implements BoardRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final LocalDatabaseService _localDatabaseService;
  static const String crdtEngine = 'crdt_v1';
  static const String _membersSubcollection = 'members';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userBoardIndexSub;
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _ownedBoardDocSubs =
      <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _joinedBoardDocSubs =
      <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
  String? _syncUserId;
  Set<String> _ownedBoardIds = <String>{};
  Set<String> _joinedBoardIds = <String>{};
  final Map<String, Map<String, dynamic>> _ownedBoardDocs =
      <String, Map<String, dynamic>>{};
  final Map<String, Map<String, dynamic>> _joinedBoardDocs =
      <String, Map<String, dynamic>>{};

  FirestoreBoardRepository({
    required FirestoreService firestoreService,
    required AuthService authService,
    required LocalDatabaseService localDatabaseService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _localDatabaseService = localDatabaseService;

  @override
  String? get currentUserId => _authService.getCurrentUserId();

  @override
  Future<int> countBoardsForUser(String userId) async {
    try {
      final userDoc = await _firestoreService
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? const <String, dynamic>{};
        final count = _toInt(data['boardCount']);
        if (count >= 0) {
          return count;
        }
      }

      final ownedSnapshot = await _firestoreService
          .collection('boards')
          .where('ownerId', isEqualTo: userId)
          .get();
      return ownedSnapshot.docs.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> startBoardsSync() async {
    final uid = currentUserId;
    if (uid == null) {
      await stopBoardsSync();
      return;
    }

    if (_syncUserId == uid && _userBoardIndexSub != null) {
      return;
    }

    await stopBoardsSync();
    _syncUserId = uid;

    _userBoardIndexSub = _firestoreService
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snapshot) async {
            final data = snapshot.data() ?? const <String, dynamic>{};
            final ownedIds = _toStringSet(data['ownedBoards']);
            final joinedIds = _toStringSet(data['joinedBoards'])
              ..removeAll(ownedIds);

            await _reconcileBoardListeners(
              ownedIds: ownedIds,
              joinedIds: joinedIds,
            );
          },
          onError: (error, stackTrace) {
            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              return;
            }
          },
        );
  }

  @override
  Future<void> stopBoardsSync() async {
    await _userBoardIndexSub?.cancel();
    _userBoardIndexSub = null;
    for (final sub in _ownedBoardDocSubs.values) {
      await sub.cancel();
    }
    for (final sub in _joinedBoardDocSubs.values) {
      await sub.cancel();
    }
    _ownedBoardDocSubs.clear();
    _joinedBoardDocSubs.clear();
    _ownedBoardDocs.clear();
    _joinedBoardDocs.clear();
    _syncUserId = null;
    _ownedBoardIds = <String>{};
    _joinedBoardIds = <String>{};
  }

  @override
  Stream<List<Board>> getOwnedBoards() {
    return _watchLocalBoards(owned: true);
  }

  @override
  Stream<List<Board>> getJoinedBoards() {
    return _watchLocalBoards(owned: false);
  }

  Stream<List<Board>> _watchLocalBoards({required bool owned}) {
    return _localDatabaseService.database.asStream().asyncExpand((isar) {
      final queryBuilder = isar.localBoards.filter();

      final filterQuery = owned
          ? queryBuilder.ownerIdEqualTo(currentUserId ?? '')
          : queryBuilder
                .membersElementEqualTo(currentUserId ?? '')
                .and()
                .not()
                .ownerIdEqualTo(currentUserId ?? '');

      return filterQuery
          .sortByUpdatedAtDesc()
          .watch(fireImmediately: true)
          .map(
            (localBoards) => localBoards
                .map(
                  (lb) => Board(
                    id: lb.boardId,
                    title: lb.title,
                    ownerId: lb.ownerId,
                    members: lb.members,
                    previewPath: lb.previewPath,
                    visibility: lb.visibility,
                    privateJoinPolicy: lb.privateJoinPolicy,
                    tags: lb.tags,
                    joinViaCodeEnabled: lb.joinViaCodeEnabled,
                    whoCanInvite: lb.whoCanInvite,
                    defaultLinkJoinRole: lb.defaultLinkJoinRole,
                    currentUserRole: lb.currentUserRole,
                    createdAt: lb.createdAt,
                    updatedAt: lb.updatedAt,
                  ),
                )
                .toList(),
          );
    });
  }

  @override
  Stream<Board?> getBoardById(String boardId) async* {
    final isar = await _localDatabaseService.database;

    yield* isar.localBoards
        .filter()
        .boardIdEqualTo(boardId)
        .watch(fireImmediately: true)
        .map((boards) {
          if (boards.isEmpty) return null;
          final lb = boards.first;
          return Board(
            id: lb.boardId,
            title: lb.title,
            ownerId: lb.ownerId,
            members: lb.members,
            previewPath: lb.previewPath,
            visibility: lb.visibility,
            privateJoinPolicy: lb.privateJoinPolicy,
            tags: lb.tags,
            joinViaCodeEnabled: lb.joinViaCodeEnabled,
            whoCanInvite: lb.whoCanInvite,
            defaultLinkJoinRole: lb.defaultLinkJoinRole,
            currentUserRole: lb.currentUserRole,
            createdAt: lb.createdAt,
            updatedAt: lb.updatedAt,
          );
        })
        .asBroadcastStream();
  }

  Future<void> _reconcileBoardListeners({
    required Set<String> ownedIds,
    required Set<String> joinedIds,
  }) async {
    _ownedBoardIds = ownedIds;
    _joinedBoardIds = joinedIds;

    await _reconcileOwnedListeners(ownedIds);
    await _reconcileJoinedListeners(joinedIds);
    await _syncCachedBoardsToLocal();
  }

  Future<void> _reconcileOwnedListeners(Set<String> ownedIds) async {
    final staleOwned = _ownedBoardDocSubs.keys
        .where((boardId) => !ownedIds.contains(boardId))
        .toList(growable: false);
    for (final boardId in staleOwned) {
      await _ownedBoardDocSubs.remove(boardId)?.cancel();
      _ownedBoardDocs.remove(boardId);
    }

    for (final boardId in ownedIds) {
      if (_ownedBoardDocSubs.containsKey(boardId)) {
        continue;
      }

      _ownedBoardDocSubs[boardId] = _firestoreService
          .collection('boards')
          .doc(boardId)
          .snapshots()
          .listen(
            (doc) {
              try {
                if (doc.exists) {
                  _ownedBoardDocs[boardId] =
                      doc.data() ?? const <String, dynamic>{};
                } else {
                  _ownedBoardDocs.remove(boardId);
                  _ownedBoardIds.remove(boardId);
                }
                _syncCachedBoardsToLocal();
              } catch (e) {
                // Silent fail
              }
            },
            onError: (error, stackTrace) {
              // Silently ignore permission errors during logout
            },
          );
    }
  }

  Future<void> _reconcileJoinedListeners(Set<String> joinedIds) async {
    final staleJoined = _joinedBoardDocSubs.keys
        .where((boardId) => !joinedIds.contains(boardId))
        .toList(growable: false);
    for (final boardId in staleJoined) {
      await _joinedBoardDocSubs.remove(boardId)?.cancel();
      _joinedBoardDocs.remove(boardId);
    }

    for (final boardId in joinedIds) {
      if (_joinedBoardDocSubs.containsKey(boardId)) {
        continue;
      }

      _joinedBoardDocSubs[boardId] = _firestoreService
          .collection('boards')
          .doc(boardId)
          .snapshots()
          .listen(
            (doc) {
              try {
                if (doc.exists) {
                  _joinedBoardDocs[boardId] =
                      doc.data() ?? const <String, dynamic>{};
                } else {
                  _joinedBoardDocs.remove(boardId);
                  _joinedBoardIds.remove(boardId);
                }
                _syncCachedBoardsToLocal();
              } catch (e) {
                // Silent fail
              }
            },
            onError: (error, stackTrace) {
              // Silently ignore permission errors during logout
            },
          );
    }
  }

  Future<void> _syncCachedBoardsToLocal() async {
    final uid = _syncUserId;
    if (uid == null) return;

    final isar = await _localDatabaseService.database;
    final updates = <String, LocalBoard>{};

    final visibleBoardIds = <String>{..._ownedBoardIds, ..._joinedBoardIds};
    for (final boardId in visibleBoardIds) {
      final data =
          _ownedBoardDocs[boardId] ??
          _joinedBoardDocs[boardId] ??
          const <String, dynamic>{};
      if (data.isEmpty) {
        continue;
      }
      final board = LocalBoard()
        ..boardId = boardId
        ..title = data['title'] ?? data['name'] ?? 'Untitled Board'
        ..ownerId = data['ownerId'] ?? ''
        ..members = List<String>.from(data['members'] ?? [])
        ..engine = data['engine'] ?? crdtEngine
        ..visibility =
            (data['visibility'] as String?) ?? Board.visibilityPrivate
        ..privateJoinPolicy =
            (data['privateJoinPolicy'] as String?) ??
            Board.policyOwnerOnlyInvite
        ..tags = List<String>.from(data['tags'] ?? const <String>[])
        ..joinViaCodeEnabled = (data['joinViaCodeEnabled'] as bool?) ?? false
        ..whoCanInvite =
            ((data['invitePolicy'] as Map<String, dynamic>?)?['whoCanInvite']
                as String?) ??
            Board.inviteOwnerOnly
        ..defaultLinkJoinRole =
            ((data['invitePolicy']
                    as Map<String, dynamic>?)?['defaultLinkJoinRole']
                as String?) ??
            Board.roleViewer
        ..currentUserRole = await _resolveCurrentUserRole(
          boardId: boardId,
          ownerId: (data['ownerId'] as String?) ?? '',
          uid: uid,
        )
        ..previewPath = (await isar.localBoards.getByBoardId(
          boardId,
        ))?.previewPath
        ..createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..updatedAt =
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..isSynced = true;
      updates[boardId] = board;
    }

    await isar.writeTxn(() async {
      for (final board in updates.values) {
        await isar.localBoards.putByBoardId(board);
      }

      final ownedLocals = await isar.localBoards
          .filter()
          .ownerIdEqualTo(uid)
          .findAll();
      final memberLocals = await isar.localBoards
          .filter()
          .membersElementEqualTo(uid)
          .findAll();

      final potentiallyVisibleLocals = <int, LocalBoard>{
        for (final board in ownedLocals) board.id: board,
        for (final board in memberLocals) board.id: board,
      }.values;

      for (final localBoard in potentiallyVisibleLocals) {
        if (!updates.containsKey(localBoard.boardId)) {
          await isar.localBoards.delete(localBoard.id);
        }
      }
    });
  }

  @override
  Future<String> createNewBoard({
    String name = 'Untitled Board',
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    required List<String> tags,
    List<String> invitedUserIds = const [],
    int inviteExpiryHours = 72,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    final firestore = _firestoreService.getInstance();
    final docRef = _firestoreService.collection('boards').doc();
    final userRef = firestore.collection('users').doc(uid);
    final now = DateTime.now();
    final normalizedVisibility = visibility == Board.visibilityPublic
        ? Board.visibilityPublic
        : Board.visibilityPrivate;
    final normalizedPrivatePolicy = privateJoinPolicy == Board.policyLinkCanJoin
        ? Board.policyLinkCanJoin
        : Board.policyOwnerOnlyInvite;
    final normalizedTags = tags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .take(5)
        .toList(growable: false);
    final normalizedWhoCanInvite = whoCanInvite == Board.inviteOwnerEditor
        ? Board.inviteOwnerEditor
        : whoCanInvite == Board.inviteAllMembers
        ? Board.inviteAllMembers
        : Board.inviteOwnerOnly;
    final normalizedDefaultLinkJoinRole =
        defaultLinkJoinRole == Board.roleEditor
        ? Board.roleEditor
        : Board.roleViewer;
    final joinViaCodeEnabled =
        normalizedVisibility == Board.visibilityPublic ||
        normalizedPrivatePolicy == Board.policyLinkCanJoin;

    final boardData = <String, dynamic>{
      'boardId': docRef.id,
      'title': name,
      'name': name,
      'ownerId': uid,
      'members': [uid],
      'engine': crdtEngine,
      'visibility': normalizedVisibility,
      'privateJoinPolicy': normalizedPrivatePolicy,
      'tags': normalizedTags,
      'joinViaCodeEnabled': joinViaCodeEnabled,
      'joinCode': docRef.id,
      'invitePolicy': {
        'whoCanInvite': normalizedWhoCanInvite,
        'defaultLinkJoinRole': normalizedDefaultLinkJoinRole,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastEditedBy': uid,
    };

    if (normalizedVisibility == Board.visibilityPrivate) {
      boardData['privateJoinPolicy'] = normalizedPrivatePolicy;
    }

    await firestore.runTransaction((transaction) async {
      transaction.set(docRef, boardData);
      transaction.set(docRef.collection(_membersSubcollection).doc(uid), {
        'uid': uid,
        'role': Board.roleOwner,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        'boardCount': FieldValue.increment(1),
        'ownedBoards': FieldValue.arrayUnion([docRef.id]),
        'joinedBoards': FieldValue.arrayRemove([docRef.id]),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    final isar = await _localDatabaseService.database;
    final newLocalBoard = LocalBoard()
      ..boardId = docRef.id
      ..title = name
      ..ownerId = uid
      ..members = [uid]
      ..engine = crdtEngine
      ..visibility = normalizedVisibility
      ..privateJoinPolicy = normalizedPrivatePolicy
      ..tags = normalizedTags
      ..joinViaCodeEnabled = joinViaCodeEnabled
      ..whoCanInvite = normalizedWhoCanInvite
      ..defaultLinkJoinRole = normalizedDefaultLinkJoinRole
      ..currentUserRole = Board.roleOwner
      ..previewPath = null
      ..createdAt = now
      ..updatedAt = now
      ..isSynced = true;

    await isar.writeTxn(() async {
      await isar.localBoards.putByBoardId(newLocalBoard);
    });

    return docRef.id;
  }

  @override
  Future<void> joinBoard(String boardId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    final firestore = _firestoreService.getInstance();
    final docRef = _firestoreService.collection('boards').doc(boardId);
    final userRef = firestore.collection('users').doc(uid);

    try {
      await firestore.runTransaction((transaction) async {
        final boardDoc = await transaction.get(docRef);
        if (!boardDoc.exists) {
          throw Exception('Board does not exist');
        }

        final boardData = boardDoc.data() ?? const <String, dynamic>{};
        final ownerId = boardData['ownerId']?.toString();
        if (ownerId == uid) {
          transaction.set(userRef, {
            'ownedBoards': FieldValue.arrayUnion([boardId]),
            'joinedBoards': FieldValue.arrayRemove([boardId]),
            'lastActive': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return;
        }

        transaction.update(docRef, {
          'members': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(userRef, {
          'joinedBoards': FieldValue.arrayUnion([boardId]),
          'ownedBoards': FieldValue.arrayRemove([boardId]),
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied while joining board');
      }
      if (e.code == 'not-found') {
        throw Exception('Board does not exist');
      }
      rethrow;
    }
  }

  @override
  Future<void> ensureBoardCached(String boardId) async {
    final uid = currentUserId;
    if (uid == null || boardId.trim().isEmpty) {
      return;
    }

    final boardSnapshot = await _firestoreService
        .collection('boards')
        .doc(boardId)
        .get();
    if (!boardSnapshot.exists) {
      return;
    }

    final boardData = boardSnapshot.data() ?? const <String, dynamic>{};
    final isar = await _localDatabaseService.database;
    final existingBoard = await isar.localBoards.getByBoardId(boardId);
    final members = List<String>.from(boardData['members'] ?? const <String>[]);
    final localBoard = existingBoard ?? LocalBoard();

    localBoard
      ..boardId = boardId
      ..title = boardData['title'] ?? boardData['name'] ?? 'Untitled Board'
      ..ownerId = boardData['ownerId'] ?? ''
      ..members = members
      ..engine = boardData['engine'] ?? crdtEngine
      ..visibility =
          (boardData['visibility'] as String?) ?? Board.visibilityPrivate
      ..privateJoinPolicy =
          (boardData['privateJoinPolicy'] as String?) ??
          Board.policyOwnerOnlyInvite
      ..tags = List<String>.from(boardData['tags'] ?? const <String>[])
      ..joinViaCodeEnabled = (boardData['joinViaCodeEnabled'] as bool?) ?? false
      ..whoCanInvite =
          ((boardData['invitePolicy'] as Map<String, dynamic>?)?['whoCanInvite']
              as String?) ??
          Board.inviteOwnerOnly
      ..defaultLinkJoinRole =
          ((boardData['invitePolicy']
                  as Map<String, dynamic>?)?['defaultLinkJoinRole']
              as String?) ??
          Board.roleViewer
      ..currentUserRole = await _resolveCurrentUserRole(
        boardId: boardId,
        ownerId: (boardData['ownerId'] as String?) ?? '',
        uid: uid,
      )
      ..previewPath = existingBoard?.previewPath
      ..createdAt =
          (boardData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
      ..updatedAt =
          (boardData['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()
      ..isSynced = true;

    await isar.writeTxn(() async {
      await isar.localBoards.putByBoardId(localBoard);
    });
  }

  @override
  Future<void> removeBoardSync(String boardId) async {
    if (boardId.trim().isEmpty) {
      return;
    }

    await _ownedBoardDocSubs.remove(boardId)?.cancel();
    await _joinedBoardDocSubs.remove(boardId)?.cancel();
    _ownedBoardDocs.remove(boardId);
    _joinedBoardDocs.remove(boardId);
    _ownedBoardIds.remove(boardId);
    _joinedBoardIds.remove(boardId);
  }

  @override
  Future<void> renameBoard(String boardId, String newName) async {
    if (currentUserId == null) return;

    final isar = await _localDatabaseService.database;
    final board = await isar.localBoards.getByBoardId(boardId);
    if (board != null) {
      board.title = newName;
      board.updatedAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.localBoards.putByBoardId(board);
      });
    }

    await _firestoreService.collection('boards').doc(boardId).update({
      'title': newName,
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteBoard(String boardId) async {
    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localBoards.deleteByBoardId(boardId);
    });
  }

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {
    if (currentUserId == null || boardId.isEmpty || pngBytes.isEmpty) {
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final previewsDir = Directory(
      '${directory.path}${Platform.pathSeparator}inklink${Platform.pathSeparator}board_previews',
    );
    if (!await previewsDir.exists()) {
      await previewsDir.create(recursive: true);
    }

    final previewFile = File(
      '${previewsDir.path}${Platform.pathSeparator}$boardId.png',
    );
    await previewFile.writeAsBytes(pngBytes, flush: true);

    final isar = await _localDatabaseService.database;
    final localBoard = await isar.localBoards.getByBoardId(boardId);
    if (localBoard == null) return;
    final canUpdateBoardMetadata =
        localBoard.currentUserRole == Board.roleOwner ||
        localBoard.currentUserRole == Board.roleEditor;

    localBoard.previewPath = previewFile.path;
    localBoard.updatedAt = DateTime.now();

    if (canUpdateBoardMetadata) {
      await _firestoreService.collection('boards').doc(boardId).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await isar.writeTxn(() async {
      await isar.localBoards.putByBoardId(localBoard);
    });
  }

  @override
  Stream<String?> watchBoardPreview(String boardId) {
    return _localDatabaseService.database.asStream().asyncExpand((isar) {
      return isar.localBoards
          .filter()
          .boardIdEqualTo(boardId)
          .watch(fireImmediately: true)
          .map((boards) => boards.isEmpty ? null : boards.first.previewPath);
    });
  }

  Set<String> _toStringSet(dynamic value) {
    if (value is! Iterable) {
      return <String>{};
    }
    return value
        .map((item) => item?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<String> _resolveCurrentUserRole({
    required String boardId,
    required String ownerId,
    required String uid,
  }) async {
    if (ownerId == uid) {
      return Board.roleOwner;
    }

    try {
      final memberDoc = await _firestoreService
          .collection('boards')
          .doc(boardId)
          .collection(_membersSubcollection)
          .doc(uid)
          .get();
      if (!memberDoc.exists) {
        return Board.roleViewer;
      }

      final role = (memberDoc.data() ?? const <String, dynamic>{})['role'];
      if (role == Board.roleEditor || role == Board.roleOwner) {
        return role as String;
      }
      return Board.roleViewer;
    } catch (_) {
      return Board.roleViewer;
    }
  }
}
