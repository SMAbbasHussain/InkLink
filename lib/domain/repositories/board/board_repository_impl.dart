import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/collections/local_board.dart';
import '../../../core/database/collections/local_crdt_update.dart';
import '../../../core/database/collections/local_profile.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/stream_registry.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/firestore_batch_fetcher.dart';
import '../../models/board.dart';
import 'board_repository.dart';

class FirestoreBoardRepository implements BoardRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final LocalDatabaseService _localDatabaseService;
  static const String crdtEngine = 'crdt_v1';
  static const String _membersSubcollection = 'members';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _userBoardIndexSub;
  StreamSubscription<User?>? _authStateSub;
  String? _syncUserId;
  Future<void>? _syncInProgress;
  String? _activeBoardId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _activeBoardMetadataSub;
  StreamController<Board?>? _activeBoardController;

  Set<String> _ownedBoardIds = <String>{};
  Set<String> _joinedBoardIds = <String>{};
  final Map<String, Map<String, dynamic>> _ownedBoardDocs =
      <String, Map<String, dynamic>>{};
  final Map<String, Map<String, dynamic>> _joinedBoardDocs =
      <String, Map<String, dynamic>>{};

  late final FirestoreBatchFetcher _batchFetcher;

  FirestoreBoardRepository({
    required FirestoreService firestoreService,
    required AuthService authService,
    required LocalDatabaseService localDatabaseService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _localDatabaseService = localDatabaseService {
    _batchFetcher = FirestoreBatchFetcher(firestoreService: firestoreService);
  }

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
    // Prevent concurrent re‑entrant calls that would cancel each other's
    // Firestore listeners and leave the sync in a broken state.
    if (_syncInProgress != null) {
      return _syncInProgress;
    }
    final future = _doStartBoardsSync();
    _syncInProgress = future;
    try {
      await future;
    } finally {
      _syncInProgress = null;
    }
  }

  Future<void> _doStartBoardsSync() async {
    final uid = currentUserId;
    if (uid == null) {
      _authStateSub ??= _authService.getInstance().authStateChanges().listen((
        user,
      ) {
        if (user != null) {
          unawaited(startBoardsSync());
        }
      });
      return;
    }

    if (_syncUserId == uid && _userBoardIndexSub != null) {
      return;
    }

    await stopBoardsSync();
    _syncUserId = uid;

    _userBoardIndexSub = StreamRegistry.instance
        .getOrCreate<QuerySnapshot<Map<String, dynamic>>>(
          'user_boards:$uid',
          () => _firestoreService
              .collection('users')
              .doc(uid)
              .collection('boards')
              .snapshots(),
        )
        .listen(
          (snapshot) async {
            try {
              final owned = <String>{};
              final joined = <String>{};

              for (final doc in snapshot.docs) {
                final data = doc.data();
                final boardId = (data['boardId'] as String?) ?? doc.id;
                final relation = (data['relation'] as String?) ?? 'joined';
                if (relation == 'owned') {
                  owned.add(boardId);
                } else {
                  joined.add(boardId);
                }
              }

              // When subcollection is empty, try fallback query for legacy
              // boards that existed before the subcollection migration.
              if (snapshot.docs.isEmpty) {
                developer.log(
                  'Board subcollection empty, trying fallback',
                  name: 'BoardRepo',
                );
                final fallback = await _fallbackSyncBoardsForUser(uid);
                if (fallback != null) {
                  owned.addAll(fallback.owned);
                  joined.addAll(fallback.joined);
                }
              }

              // Ensure owned set does not appear in joined
              joined.removeAll(owned);

              _ownedBoardIds = owned;
              _joinedBoardIds = joined;

              developer.log(
                'Board IDs resolved: owned=$owned joined=$joined',
                name: 'BoardRepo',
              );

              final activeBoardId = _activeBoardId;
              if (activeBoardId != null &&
                  !_ownedBoardIds.contains(activeBoardId) &&
                  !_joinedBoardIds.contains(activeBoardId)) {
                await deactivateBoard();
              }

              await _syncVisibleBoardsToLocal(
                visibleBoardIds: {..._ownedBoardIds, ..._joinedBoardIds},
              );
            } catch (e, st) {
              developer.log(
                'Board sync failed: $e',
                name: 'BoardRepo',
                error: e,
                stackTrace: st,
              );
            }
          },
          onError: (error, stackTrace) {
            developer.log(
              'Board sync stream error: $error',
              name: 'BoardRepo',
              error: error,
              stackTrace: stackTrace,
            );
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
    await _authStateSub?.cancel();
    _authStateSub = null;
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

    if (_activeBoardId == trimmedBoardId && _activeBoardMetadataSub != null) {
      return;
    }

    await deactivateBoard();

    _activeBoardId = trimmedBoardId;
    _activeBoardController = StreamController<Board?>.broadcast();

    // Phase 4A: Separate listener for board metadata
    _activeBoardMetadataSub = StreamRegistry.instance
        .getOrCreate<DocumentSnapshot<Map<String, dynamic>>>(
          'board_doc:$trimmedBoardId',
          () => _firestoreService
              .collection('boards')
              .doc(trimmedBoardId)
              .snapshots(),
        )
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
    await _activeBoardMetadataSub?.cancel();
    _activeBoardMetadataSub = null;
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
    final controller = StreamController<List<Board>>.broadcast();
    StreamSubscription<User?>? authSub;
    StreamSubscription<List<LocalBoard>>? localSub;
    var syncGeneration = 0;

    Future<void> bindToUser(String? uid) async {
      final callGeneration = syncGeneration;
      await localSub?.cancel();
      if (callGeneration != syncGeneration) {
        return;
      }
      localSub = null;

      if (uid == null || uid.isEmpty) {
        if (!controller.isClosed) {
          controller.add(const <Board>[]);
        }
        return;
      }

      final isar = await _localDatabaseService.database;
      if (callGeneration != syncGeneration || controller.isClosed) {
        return;
      }
      final queryBuilder = isar.localBoards.filter();

      final filterQuery = owned
          ? queryBuilder.ownerIdEqualTo(uid)
          : queryBuilder
                .membersElementEqualTo(uid)
                .and()
                .not()
                .ownerIdEqualTo(uid);

      final nextLocalSub = filterQuery
          .sortByUpdatedAtDesc()
          .watch(fireImmediately: true)
          .listen((localBoards) {
            if (controller.isClosed) {
              return;
            }

            developer.log(
              'Isar ${owned ? "owned" : "joined"} boards watcher fired: ${localBoards.length} boards',
              name: 'BoardRepo',
            );

            controller.add(
              localBoards
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
          }, onError: controller.addError);

      if (callGeneration != syncGeneration || controller.isClosed) {
        await nextLocalSub.cancel();
        return;
      }

      localSub = nextLocalSub;
    }

    controller.onListen = () {
      syncGeneration++;
      authSub = _authService.getInstance().authStateChanges().listen((user) {
        unawaited(bindToUser(user?.uid));
      }, onError: controller.addError);

      unawaited(bindToUser(currentUserId));
    };

    controller.onCancel = () async {
      syncGeneration++;
      await authSub?.cancel();
      authSub = null;
      await localSub?.cancel();
      localSub = null;
    };

    return controller.stream;
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

          // Collect UIDs and map member fields from members subcollection
          final uids = <String>[];
          final memberFieldsByUid = <String, Map<String, dynamic>>{};
          for (final doc in membersSnapshot.docs) {
            final data = doc.data();
            final uid = doc.id;
            uids.add(uid);
            memberFieldsByUid[uid] = data;
          }

          if (uids.isEmpty) return <BoardMember>[];

          // First consult local Isar cache for profiles
          final isar = await _localDatabaseService.database;
          final cachedProfiles = <String, Map<String, dynamic>>{};
          for (final uid in uids) {
            final localProfile = await isar.localProfiles
                .filter()
                .uidEqualTo(uid)
                .findFirst();

            if (localProfile != null) {
              cachedProfiles[uid] = {
                'displayName': localProfile.displayName,
                'email': localProfile.email,
                'photoURL': localProfile.photoURL,
              };
            }
          }

          // Determine missing UIDs to fetch via whereIn batching
          final missingUids = uids
              .where((u) => !cachedProfiles.containsKey(u))
              .toList();
          final fetchedProfiles = <String, Map<String, dynamic>>{};

          const chunkSize = 30;
          for (var i = 0; i < missingUids.length; i += chunkSize) {
            final chunk = missingUids.sublist(
              i,
              (i + chunkSize).clamp(0, missingUids.length),
            );
            try {
              final snapshot = await _firestoreService
                  .collection('users')
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get();
              for (final doc in snapshot.docs) {
                fetchedProfiles[doc.id] = doc.data();
              }
            } catch (_) {
              // Fallback: individual gets
              for (final id in chunk) {
                final doc = await _firestoreService
                    .collection('users')
                    .doc(id)
                    .get();
                if (doc.exists) {
                  fetchedProfiles[id] = doc.data() ?? const <String, dynamic>{};
                }
              }
            }
          }

          // Merge cached + fetched and build BoardMember list
          for (final uid in uids) {
            final data = memberFieldsByUid[uid] ?? {};
            final role = data['role'] as String? ?? 'viewer';
            final status = data['status'] as String? ?? 'active';
            final joinedAt = data['joinedAt'] != null
                ? (data['joinedAt'] as Timestamp).toDate()
                : null;

            final profile = cachedProfiles[uid] ?? fetchedProfiles[uid];

            final displayName = profile?['displayName'] as String?;
            final email = profile?['email'] as String?;
            final photoUrl = profile?['photoURL'] as String?;

            // Persist fetched profiles to local cache for future use
            if (profile != null && !cachedProfiles.containsKey(uid)) {
              unawaited(
                isar.writeTxn(() async {
                  await isar.localProfiles.put(
                    LocalProfile(
                      uid: uid,
                      displayName: displayName ?? '',
                      email: email,
                      photoURL: photoUrl,
                      friendshipStatus: FriendshipStatus.nonFriend,
                      cachedAtOverride: DateTime.now(),
                    ),
                  );
                }),
              );
            }

            members.add(
              BoardMember(
                uid: uid,
                role: role,
                status: status,
                joinedAt: joinedAt,
                displayName: displayName,
                email: email,
                photoUrl: photoUrl,
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
    if (uid == null) {
      developer.log(
        'Board sync: _syncUserId is null, skipping $boardId',
        name: 'BoardRepo',
      );
      return;
    }

    developer.log(
      'Board sync: writing $boardId to Isar',
      name: 'BoardRepo',
    );

    try {
      final isar = await _localDatabaseService.database;
      final existingBoard = await isar.localBoards.getByBoardId(boardId);
      final localBoard = existingBoard ?? LocalBoard();

      localBoard
        ..boardId = boardId
        ..title = data['title'] ?? data['name'] ?? 'Untitled Board'
        ..ownerId = data['ownerId'] ?? ''
        ..members = List<String>.from(data['members'] ?? const <String>[])
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
        ..previewPath = existingBoard?.previewPath
        ..createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..updatedAt =
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..isSynced = true;

      await isar.writeTxn(() async {
        await isar.localBoards.putByBoardId(localBoard);
      });

      developer.log(
        'Board sync: $boardId written to Isar successfully',
        name: 'BoardRepo',
      );
    } catch (e, st) {
      developer.log(
        'Board sync: _syncSingleBoardToLocal failed for $boardId: $e',
        name: 'BoardRepo',
        error: e,
        stackTrace: st,
      );
    }
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

  /// Fallback: query the boards collection directly when `users/{uid}/boards`
  /// subcollection is empty but the user may have legacy boards that existed
  /// before the subcollection migration was deployed.
  Future<({Set<String> owned, Set<String> joined})?> _fallbackSyncBoardsForUser(
    String uid,
  ) async {
    try {
      final userDoc = await _firestoreService
          .collection('users')
          .doc(uid)
          .get();
      final count = _toInt(userDoc.data()?['boardCount']);
      if (count <= 0) return null;

      final snapshot = await _firestoreService
          .collection('boards')
          .where('ownerId', isEqualTo: uid)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final owned = snapshot.docs.map((doc) => doc.id).toSet();
      return (owned: owned, joined: <String>{});
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncVisibleBoardsToLocal({
    required Set<String> visibleBoardIds,
  }) async {
    if (visibleBoardIds.isEmpty) {
      developer.log(
        'Board sync: no visible board IDs, clearing cache',
        name: 'BoardRepo',
      );
      _ownedBoardDocs.clear();
      _joinedBoardDocs.clear();
      await _pruneLocalBoards(visibleBoardIds: visibleBoardIds);
      return;
    }

    developer.log(
      'Board sync: fetching ${visibleBoardIds.length} boards',
      name: 'BoardRepo',
    );

    final fetchResult = await _batchFetcher.fetchDocumentsByIdSet(
      collectionPath: 'boards',
      ids: visibleBoardIds.toList(growable: false),
    );

    developer.log(
      'Board sync: fetched=${fetchResult.docsById.length} missing=${fetchResult.missingIds.length}',
      name: 'BoardRepo',
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
      'memberCount': 1,
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
      }, SetOptions(merge: true));

      transaction.set(userRef.collection('boards').doc(docRef.id), {
        'boardId': docRef.id,
        'relation': 'owned',
        'addedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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
          transaction.set(userRef.collection('boards').doc(boardId), {
            'boardId': boardId,
            'relation': 'owned',
            'addedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return;
        }

        transaction.update(docRef, {
          'members': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(userRef.collection('boards').doc(boardId), {
          'boardId': boardId,
          'relation': 'joined',
          'addedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
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
      await isar.localCrdtUpdates.filter().boardIdEqualTo(boardId).deleteAll();
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
    // Updating top-level board metadata is owner-scoped in security rules.
    // Do not attempt this write for non-owners when closing/saving preview.
    final canUpdateBoardMetadata =
        localBoard.currentUserRole == Board.roleOwner ||
        localBoard.ownerId == currentUserId;

    localBoard.previewPath = previewFile.path;
    localBoard.updatedAt = DateTime.now();

    if (canUpdateBoardMetadata) {
      try {
        await _firestoreService.collection('boards').doc(boardId).update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') {
          rethrow;
        }
      }
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
