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
  String? _syncUserId;
  String? _activeBoardId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _activeBoardSub;
  StreamController<Board?>? _activeBoardController;
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

      final aggregate = await _firestoreService
          .collection('boards')
          .where('ownerId', isEqualTo: userId)
          .count()
          .get();
      return aggregate.count ?? 0;
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
            try {
              final data = snapshot.data() ?? const <String, dynamic>{};
              final ownedIds = _toStringSet(data['ownedBoards']);
              final joinedIds = _toStringSet(data['joinedBoards'])
                ..removeAll(ownedIds);

              _ownedBoardIds = ownedIds;
              _joinedBoardIds = joinedIds;

              final activeBoardId = _activeBoardId;
              if (activeBoardId != null &&
                  !_ownedBoardIds.contains(activeBoardId) &&
                  !_joinedBoardIds.contains(activeBoardId)) {
                await deactivateBoard();
              }

              await _syncVisibleBoardsToLocal(
                visibleBoardIds: {..._ownedBoardIds, ..._joinedBoardIds},
              );
            } catch (_) {
              // Keep the previous sync state on transient snapshot issues.
            }
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
    await deactivateBoard();
    await _userBoardIndexSub?.cancel();
    _userBoardIndexSub = null;
    _ownedBoardDocs.clear();
    _joinedBoardDocs.clear();
    _syncUserId = null;
    _ownedBoardIds = <String>{};
    _joinedBoardIds = <String>{};
  }

  @override
  Future<void> activateBoard(String boardId) async {
    final trimmedBoardId = boardId.trim();
    if (trimmedBoardId.isEmpty) {
      return;
    }

    if (_activeBoardId == trimmedBoardId && _activeBoardSub != null) {
      return;
    }

    await deactivateBoard();

    _activeBoardId = trimmedBoardId;
    _activeBoardController = StreamController<Board?>.broadcast();
    _activeBoardSub = _firestoreService
        .collection('boards')
        .doc(trimmedBoardId)
        .snapshots()
        .listen(
          (doc) async {
            try {
              if (!doc.exists) {
                _ownedBoardDocs.remove(trimmedBoardId);
                _joinedBoardDocs.remove(trimmedBoardId);
                _activeBoardController?.add(null);
                await _deleteLocalBoard(trimmedBoardId);
                return;
              }

              final data = doc.data() ?? const <String, dynamic>{};
              if (_ownedBoardIds.contains(trimmedBoardId)) {
                _ownedBoardDocs[trimmedBoardId] = data;
              } else {
                _joinedBoardDocs[trimmedBoardId] = data;
              }

              await _syncSingleBoardToLocal(trimmedBoardId, data);
              _activeBoardController?.add(
                await _loadLocalBoard(trimmedBoardId),
              );
            } catch (_) {
              // Keep the active board stream alive on transient failures.
            }
          },
          onError: (error, stackTrace) {
            _activeBoardController?.add(null);
          },
        );
  }

  @override
  Future<void> deactivateBoard() async {
    final activeBoardId = _activeBoardId;
    await _activeBoardSub?.cancel();
    _activeBoardSub = null;
    if (_activeBoardController != null && !_activeBoardController!.isClosed) {
      await _activeBoardController!.close();
    }
    _activeBoardController = null;
    if (activeBoardId != null) {
      _ownedBoardDocs.remove(activeBoardId);
      _joinedBoardDocs.remove(activeBoardId);
    }
    _activeBoardId = null;
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
  Stream<List<BoardMember>> getBoardMembers(String boardId) {
    return _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection(_membersSubcollection)
        .snapshots()
        .asyncMap((membersSnapshot) async {
          if (membersSnapshot.docs.isEmpty) {
            return <BoardMember>[];
          }

          final members = <BoardMember>[];
          for (final doc in membersSnapshot.docs) {
            final data = doc.data();
            final uid = doc.id;
            final role = data['role'] as String? ?? 'viewer';
            final status = data['status'] as String? ?? 'active';
            final joinedAt = data['joinedAt'] != null
                ? (data['joinedAt'] as Timestamp).toDate()
                : null;

            // Fetch user data for display name, email, photoUrl
            final userDoc = await _firestoreService
                .collection('users')
                .doc(uid)
                .get();
            final userData = userDoc.data();

            members.add(
              BoardMember(
                uid: uid,
                role: role,
                status: status,
                joinedAt: joinedAt,
                displayName: userData?['displayName'] as String?,
                email: userData?['email'] as String?,
                photoUrl: userData?['photoURL'] as String?,
              ),
            );
          }
          return members;
        });
  }

  @override
  Stream<Board?> getBoardById(String boardId) async* {
    await activateBoard(boardId);
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

  Future<void> _syncSingleBoardToLocal(
    String boardId,
    Map<String, dynamic> data,
  ) async {
    final uid = _syncUserId;
    if (uid == null) return;

    final isar = await _localDatabaseService.database;
    final existingBoard = await isar.localBoards.getByBoardId(boardId);
    final localBoard = existingBoard ?? LocalBoard();

    localBoard
      ..boardId = boardId
      ..title = data['title'] ?? data['name'] ?? 'Untitled Board'
      ..ownerId = data['ownerId'] ?? ''
      ..members = List<String>.from(data['members'] ?? const <String>[])
      ..engine = data['engine'] ?? crdtEngine
      ..visibility = (data['visibility'] as String?) ?? Board.visibilityPrivate
      ..privateJoinPolicy =
          (data['privateJoinPolicy'] as String?) ?? Board.policyOwnerOnlyInvite
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
      ..previewPath = existingBoard?.previewPath
      ..createdAt =
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
      ..updatedAt =
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()
      ..isSynced = true;

    await isar.writeTxn(() async {
      await isar.localBoards.putByBoardId(localBoard);
    });
  }

  Future<Board?> _loadLocalBoard(String boardId) async {
    final isar = await _localDatabaseService.database;
    final localBoard = await isar.localBoards.getByBoardId(boardId);
    if (localBoard == null) {
      return null;
    }
    return _mapLocalBoard(localBoard);
  }

  Future<void> _deleteLocalBoard(String boardId) async {
    final isar = await _localDatabaseService.database;
    final localBoard = await isar.localBoards.getByBoardId(boardId);
    if (localBoard == null) {
      return;
    }

    await isar.writeTxn(() async {
      await isar.localBoards.delete(localBoard.id);
    });
  }

  Future<void> _syncVisibleBoardsToLocal({
    required Set<String> visibleBoardIds,
  }) async {
    if (visibleBoardIds.isEmpty) {
      _ownedBoardDocs.clear();
      _joinedBoardDocs.clear();
      await _pruneLocalBoards(visibleBoardIds: visibleBoardIds);
      return;
    }

    final fetchResult = await _fetchBoardDocumentsByIdSet(
      ids: visibleBoardIds.toList(growable: false),
    );

    for (final entry in fetchResult.docsById.entries) {
      final boardId = entry.key;
      final boardData = entry.value;

      if (_ownedBoardIds.contains(boardId)) {
        _ownedBoardDocs[boardId] = boardData;
        _joinedBoardDocs.remove(boardId);
      } else {
        _joinedBoardDocs[boardId] = boardData;
        _ownedBoardDocs.remove(boardId);
      }

      await _syncSingleBoardToLocal(boardId, boardData);
    }

    for (final missingBoardId in fetchResult.missingIds) {
      _ownedBoardDocs.remove(missingBoardId);
      _joinedBoardDocs.remove(missingBoardId);
      await _deleteLocalBoard(missingBoardId);
    }

    final prunableBoardIds = Set<String>.from(visibleBoardIds)
      ..removeAll(fetchResult.missingIds);
    await _pruneLocalBoards(visibleBoardIds: prunableBoardIds);
  }

  Future<_BoardFetchResult> _fetchBoardDocumentsByIdSet({
    required List<String> ids,
  }) async {
    final docsById = <String, Map<String, dynamic>>{};
    final missingIds = <String>{};
    final uniqueIds = ids.toSet().toList(growable: false);
    const chunkSize = 30;

    for (var i = 0; i < uniqueIds.length; i += chunkSize) {
      final chunk = uniqueIds.sublist(
        i,
        (i + chunkSize).clamp(0, uniqueIds.length),
      );

      try {
        final snapshot = await _firestoreService
            .collection('boards')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          docsById[doc.id] = doc.data();
        }

        final foundIds = snapshot.docs.map((doc) => doc.id).toSet();
        final missingChunkIds = chunk
            .where((id) => !foundIds.contains(id))
            .toList(growable: false);

        for (final id in missingChunkIds) {
          try {
            final doc = await _firestoreService
                .collection('boards')
                .doc(id)
                .get();
            if (doc.exists) {
              docsById[id] = doc.data() ?? const <String, dynamic>{};
            } else {
              missingIds.add(id);
            }
          } catch (_) {
            // Keep existing local data when doc checks fail transiently.
          }
        }
      } catch (_) {
        for (final id in chunk) {
          try {
            final doc = await _firestoreService
                .collection('boards')
                .doc(id)
                .get();
            if (doc.exists) {
              docsById[id] = doc.data() ?? const <String, dynamic>{};
            } else {
              missingIds.add(id);
            }
          } catch (_) {
            // Keep existing local data when doc checks fail transiently.
          }
        }
      }
    }

    return _BoardFetchResult(docsById: docsById, missingIds: missingIds);
  }

  Future<void> _pruneLocalBoards({required Set<String> visibleBoardIds}) async {
    final isar = await _localDatabaseService.database;
    final localBoards = await isar.localBoards.where().findAll();
    final toDelete = localBoards
        .where((board) => !visibleBoardIds.contains(board.boardId))
        .map((board) => board.id)
        .toList(growable: false);

    if (toDelete.isEmpty) {
      return;
    }

    await isar.writeTxn(() async {
      await isar.localBoards.deleteAll(toDelete);
    });
  }

  Board _mapLocalBoard(LocalBoard lb) {
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

    if (_activeBoardId == boardId) {
      await deactivateBoard();
    }
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

class _BoardFetchResult {
  final Map<String, Map<String, dynamic>> docsById;
  final Set<String> missingIds;

  const _BoardFetchResult({required this.docsById, required this.missingIds});
}
