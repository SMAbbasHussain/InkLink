import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar_community/isar.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/database/collections/local_board.dart';
import '../../../core/database/collections/local_workspace.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../models/board.dart';
import '../../models/user_model.dart';
import '../../models/workspace.dart';
import 'workspace_repository.dart';

class FirestoreWorkspaceRepository implements WorkspaceRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final LocalDatabaseService _localDatabaseService;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userWorkspaceSub;
  String? _syncUserId;
  Set<String> _ownedWorkspaceIds = {};
  Set<String> _memberWorkspaceIds = {};
  final Map<String, Map<String, dynamic>> _ownedWorkspaceDocs = {};
  final Map<String, Map<String, dynamic>> _memberWorkspaceDocs = {};
  StreamController<List<Workspace>>? _ownedWorkspacesController;
  StreamController<List<Workspace>>? _memberWorkspacesController;

  FirestoreWorkspaceRepository({
    required FirestoreService firestoreService,
    required AuthService authService,
    required LocalDatabaseService localDatabaseService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _localDatabaseService = localDatabaseService;

  @override
  String? get currentUserId => _authService.getCurrentUserId();

  @override
  Future<void> startWorkspaceSync() async {
    final uid = currentUserId;
    if (uid == null) {
      await stopWorkspaceSync();
      return;
    }

    if (_syncUserId == uid && _userWorkspaceSub != null) {
      return;
    }

    await stopWorkspaceSync();
    _syncUserId = uid;
    _ensureWorkspaceStreamControllers();

    // Listen to user document for workspaceIds array
    _userWorkspaceSub = _firestoreService
        .collection(FirestorePaths.users)
        .doc(uid)
        .snapshots()
        .listen(
          (userSnapshot) async {
            try {
              if (!userSnapshot.exists) {
                await _reconcileWorkspaceListeners(
                  workspaceIds: const <String>{},
                );
                return;
              }

              final userData = userSnapshot.data() ?? {};
              final workspaceIds =
                  (userData[FirestorePaths.workspaceIds] as List<dynamic>?)
                      ?.cast<String>() ??
                  [];

              // If no workspaceIds, no workspaces to sync
              if (workspaceIds.isEmpty) {
                await _reconcileWorkspaceListeners(
                  workspaceIds: const <String>{},
                );
                return;
              }

              try {
                await _reconcileWorkspaceListeners(workspaceIds: workspaceIds);
              } catch (e) {
                // Handle permission errors gracefully - reconcile with empty to show local cache
                await _reconcileWorkspaceListeners(
                  workspaceIds: const <String>{},
                );
              }
            } catch (e) {
              // Silent fail on listener errors to prevent crashes
            }
          },
          onError: (error) {
            // Silently handle listener errors (e.g., permission denied on logout)
          },
        );
  }

  @override
  Future<void> stopWorkspaceSync() async {
    await _userWorkspaceSub?.cancel();
    _userWorkspaceSub = null;
    _ownedWorkspaceDocs.clear();
    _memberWorkspaceDocs.clear();
    _syncUserId = null;
    _ownedWorkspaceIds = {};
    _memberWorkspaceIds = {};

    await _ownedWorkspacesController?.close();
    await _memberWorkspacesController?.close();
    _ownedWorkspacesController = null;
    _memberWorkspacesController = null;
  }

  void _ensureWorkspaceStreamControllers() {
    _ownedWorkspacesController ??=
        StreamController<List<Workspace>>.broadcast();
    _memberWorkspacesController ??=
        StreamController<List<Workspace>>.broadcast();
  }

  void _emitWorkspaceStreams() {
    final ownedController = _ownedWorkspacesController;
    final memberController = _memberWorkspacesController;
    if (ownedController == null || memberController == null) {
      return;
    }

    ownedController.add(_currentOwnedWorkspaces());
    memberController.add(_currentMemberWorkspaces());
  }

  List<Workspace> _currentOwnedWorkspaces() {
    return _ownedWorkspaceDocs.entries
        .map((entry) => _mapFirestoreWorkspace(entry.key, entry.value))
        .toList();
  }

  List<Workspace> _currentMemberWorkspaces() {
    return _memberWorkspaceDocs.entries
        .map((entry) => _mapFirestoreWorkspace(entry.key, entry.value))
        .toList();
  }

  @override
  Stream<List<Workspace>> getOwnedWorkspaces() {
    return (() async* {
      _ensureWorkspaceStreamControllers();
      yield _currentOwnedWorkspaces();
      yield* _ownedWorkspacesController!.stream;
    })();
  }

  @override
  Stream<List<Workspace>> getMemberWorkspaces() {
    return (() async* {
      _ensureWorkspaceStreamControllers();
      yield _currentMemberWorkspaces();
      yield* _memberWorkspacesController!.stream;
    })();
  }

  @override
  Stream<Workspace?> getWorkspaceById(String workspaceId) async* {
    yield* _firestoreService
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          final data = snapshot.data() ?? {};
          return _mapFirestoreWorkspace(workspaceId, data);
        });
  }

  Future<Map<String, Map<String, dynamic>>> _fetchDocumentsByIdSet({
    required String collectionPath,
    required List<String> ids,
  }) async {
    final documentsById = <String, Map<String, dynamic>>{};
    final uniqueIds = ids.toSet().toList();
    const chunkSize = 30;

    for (var i = 0; i < uniqueIds.length; i += chunkSize) {
      final chunk = uniqueIds.sublist(
        i,
        (i + chunkSize).clamp(0, uniqueIds.length),
      );

      try {
        final snapshot = await _firestoreService
            .collection(collectionPath)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          documentsById[doc.id] = doc.data();
        }
      } catch (_) {
        for (final id in chunk) {
          try {
            final doc = await _firestoreService
                .collection(collectionPath)
                .doc(id)
                .get();
            if (doc.exists) {
              documentsById[id] = doc.data() ?? {};
            }
          } catch (_) {
            // Keep missing or inaccessible documents out of the cache.
          }
        }
      }
    }

    return documentsById;
  }

  @override
  Stream<List<Board>> getWorkspaceBoards(String workspaceId, {int? limit}) {
    return _firestoreService
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId)
        .collection(FirestorePaths.workspaceBoardsSubcollection)
        .snapshots()
        .asyncMap((snapshot) async {
          final currentUid = currentUserId;
          if (currentUid == null) {
            return <Board>[];
          }

          final userSnapshot = await _firestoreService
              .collection(FirestorePaths.users)
              .doc(currentUid)
              .get();
          final userData = userSnapshot.data() ?? {};
          final ownedBoards =
              (userData[FirestorePaths.ownedBoards] as List<dynamic>?)
                  ?.whereType<String>()
                  .toSet() ??
              <String>{};
          final joinedBoards =
              (userData[FirestorePaths.joinedBoards] as List<dynamic>?)
                  ?.whereType<String>()
                  .toSet() ??
              <String>{};
          final readableBoardIds = {...ownedBoards, ...joinedBoards};

          final isar = await _localDatabaseService.database;
          final localBoards = await isar.localBoards.where().anyId().findAll();
          final localPreviewByBoardId = {
            for (final localBoard in localBoards)
              localBoard.boardId: localBoard.previewPath,
          };
          final visibleBoardIds = <String>[];
          for (final linkDoc in snapshot.docs) {
            final linkData = linkDoc.data();
            if (linkData.containsKey('visible') &&
                linkData['visible'] != true) {
              continue;
            }
            final linkedBoardId =
                (linkData[FirestorePaths.boardId] as String?) ?? linkDoc.id;
            if (linkedBoardId.isNotEmpty &&
                readableBoardIds.contains(linkedBoardId)) {
              visibleBoardIds.add(linkedBoardId);
            }
          }

          if (visibleBoardIds.isEmpty) {
            return <Board>[];
          }

          final boardDataById = await _fetchDocumentsByIdSet(
            collectionPath: FirestorePaths.boards,
            ids: visibleBoardIds,
          );

          final boards = <Board>[];
          for (final linkedBoardId in visibleBoardIds) {
            final boardData = boardDataById[linkedBoardId];
            if (boardData == null) {
              continue;
            }
            final firestoreBoardData = Map<String, dynamic>.from(boardData);
            firestoreBoardData['currentUserRole'] =
                firestoreBoardData[FirestorePaths.ownerId] == currentUid
                ? Board.roleOwner
                : Board.roleViewer;
            final firestoreBoard = Board.fromMap(
              firestoreBoardData,
              linkedBoardId,
            );
            final localPreviewPath = localPreviewByBoardId[linkedBoardId];
            boards.add(
              Board(
                id: firestoreBoard.id,
                title: firestoreBoard.title,
                ownerId: firestoreBoard.ownerId,
                members: firestoreBoard.members,
                previewPath:
                    (localPreviewPath != null && localPreviewPath.isNotEmpty)
                    ? localPreviewPath
                    : firestoreBoard.previewPath,
                visibility: firestoreBoard.visibility,
                privateJoinPolicy: firestoreBoard.privateJoinPolicy,
                tags: firestoreBoard.tags,
                joinViaCodeEnabled: firestoreBoard.joinViaCodeEnabled,
                whoCanInvite: firestoreBoard.whoCanInvite,
                defaultLinkJoinRole: firestoreBoard.defaultLinkJoinRole,
                currentUserRole: firestoreBoard.currentUserRole,
                createdAt: firestoreBoard.createdAt,
                updatedAt: firestoreBoard.updatedAt,
              ),
            );
          }

          boards.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          if (limit != null && boards.length > limit) {
            return boards.take(limit).toList();
          }
          return boards;
        });
  }

  @override
  Stream<List<WorkspaceMember>> getWorkspaceMembers(String workspaceId) {
    return _firestoreService
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId)
        .collection(FirestorePaths.workspaceMembersSubcollection)
        .snapshots()
        .asyncMap((snapshot) async {
          final isar = await _localDatabaseService.database;
          final uids = <String>[];
          for (final memberDoc in snapshot.docs) {
            final memberData = memberDoc.data();
            final uid =
                (memberData[FirestorePaths.uid] as String?) ?? memberDoc.id;
            if (uid.isNotEmpty) {
              uids.add(uid);
            }
          }

          final userDataByUid = await _fetchDocumentsByIdSet(
            collectionPath: FirestorePaths.users,
            ids: uids,
          );
          final cachedUsers = await isar.userModels.getAllByUid(uids);
          final cachedUserByUid = {
            for (var index = 0; index < uids.length; index++)
              uids[index]: cachedUsers[index],
          };

          final members = <WorkspaceMember>[];
          for (final memberDoc in snapshot.docs) {
            final memberData = memberDoc.data();
            final uid =
                (memberData[FirestorePaths.uid] as String?) ?? memberDoc.id;
            String? displayName;
            String? email;
            String? photoUrl;

            final cachedUser = cachedUserByUid[uid];
            final userData = userDataByUid[uid];
            final cachedDisplayName = cachedUser?.displayName;
            final cachedEmail = cachedUser?.email;
            final cachedPhotoUrl = cachedUser?.photoURL;

            if (cachedDisplayName != null &&
                cachedDisplayName.trim().isNotEmpty) {
              displayName = cachedDisplayName;
            }
            if (cachedEmail != null && cachedEmail.trim().isNotEmpty) {
              email = cachedEmail;
            }
            if (cachedPhotoUrl != null && cachedPhotoUrl.trim().isNotEmpty) {
              photoUrl = cachedPhotoUrl;
            }

            if (userData != null) {
              displayName =
                  displayName ??
                  userData[FirestorePaths.displayName] as String?;
              email = email ?? userData[FirestorePaths.email] as String?;
              photoUrl =
                  photoUrl ?? userData[FirestorePaths.photoURL] as String?;
            }

            members.add(
              WorkspaceMember(
                uid: uid,
                role: (memberData['role'] as String?) ?? 'member',
                status:
                    (memberData[FirestorePaths.status] as String?) ?? 'active',
                joinedAt: (memberData['joinedAt'] as Timestamp?)?.toDate(),
                displayName: displayName,
                email: email,
                photoUrl: photoUrl,
              ),
            );
          }

          const roleOrder = {'owner': 0, 'editor': 1, 'member': 2, 'viewer': 3};
          members.sort((a, b) {
            final aRank = roleOrder[a.role] ?? 99;
            final bRank = roleOrder[b.role] ?? 99;
            if (aRank != bRank) {
              return aRank.compareTo(bRank);
            }
            return a.label.toLowerCase().compareTo(b.label.toLowerCase());
          });
          return members;
        });
  }

  @override
  Future<String> createWorkspace({
    required String name,
    required String description,
    List<String>? boardIds,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    final firestore = _firestoreService.getInstance();
    final docRef = _firestoreService
        .collection(FirestorePaths.workspaces)
        .doc();

    await firestore.runTransaction((transaction) async {
      transaction.set(docRef, {
        FirestorePaths.workspaceId: docRef.id,
        FirestorePaths.ownerId: uid,
        FirestorePaths.name: name,
        FirestorePaths.description: description,
        FirestorePaths.memberCount: 1,
        FirestorePaths.boardCount: boardIds?.length ?? 0,
        FirestorePaths.createdAt: FieldValue.serverTimestamp(),
        FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.set(
        docRef
            .collection(FirestorePaths.workspaceMembersSubcollection)
            .doc(uid),
        {
          FirestorePaths.uid: uid,
          'role': 'owner',
          FirestorePaths.status: 'active',
          'joinedAt': FieldValue.serverTimestamp(),
          FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
        },
      );

      // Add selected boards to workspace
      if (boardIds != null && boardIds.isNotEmpty) {
        for (final boardId in boardIds) {
          transaction.set(
            docRef
                .collection(FirestorePaths.workspaceBoardsSubcollection)
                .doc(boardId),
            {
              FirestorePaths.boardId: boardId,
              'visible': true,
              'addedAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      // Add workspace ID to user's workspaceIds array
      transaction.update(firestore.collection(FirestorePaths.users).doc(uid), {
        FirestorePaths.workspaceIds: FieldValue.arrayUnion([docRef.id]),
      });
    });

    // Save to local database
    try {
      final isar = (await _localDatabaseService.database);
      final localWorkspace = LocalWorkspace()
        ..workspaceId = docRef.id
        ..ownerId = uid
        ..name = name
        ..description = description
        ..memberCount = 1
        ..boardCount = boardIds?.length ?? 0
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now()
        ..currentUserRole = 'owner'
        ..isSynced = true;

      await isar.writeTxn(() async {
        await isar.localWorkspaces.put(localWorkspace);
      });
    } catch (e) {
      // Silently fail if Isar is not available
    }

    return docRef.id;
  }

  @override
  Future<void> updateWorkspace({
    required String workspaceId,
    required String name,
    required String description,
  }) async {
    await _firestoreService
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId)
        .update({
          FirestorePaths.name: name,
          FirestorePaths.description: description,
          FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> deleteWorkspace(String workspaceId) async {
    final firestore = _firestoreService.getInstance();
    final workspaceRef = _firestoreService
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId);

    await firestore.runTransaction((transaction) async {
      // Delete workspace doc and all subcollections handled by caller or backend
      transaction.delete(workspaceRef);
    });
  }

  @override
  Future<void> inviteToWorkspace({
    required String workspaceId,
    required List<String> invitedUserIds,
  }) async {
    final firestore = _firestoreService.getInstance();
    final batch = firestore.batch();
    final normalizedInvitees = <String>[];

    for (final rawIdentifier in invitedUserIds) {
      final identifier = rawIdentifier.trim();
      if (identifier.isEmpty) continue;

      if (identifier.contains('@')) {
        final normalizedEmail = identifier.toLowerCase();
        final lookups = <Future<QuerySnapshot<Map<String, dynamic>>>>[
          firestore
              .collection(FirestorePaths.users)
              .where(FirestorePaths.email, isEqualTo: normalizedEmail)
              .limit(1)
              .get(),
        ];
        if (identifier != normalizedEmail) {
          lookups.add(
            firestore
                .collection(FirestorePaths.users)
                .where(FirestorePaths.email, isEqualTo: identifier)
                .limit(1)
                .get(),
          );
        }

        final snapshots = await Future.wait(lookups);
        final normalizedSnapshot = snapshots.first;
        if (normalizedSnapshot.docs.isNotEmpty) {
          normalizedInvitees.add(normalizedSnapshot.docs.first.id);
          continue;
        }

        if (snapshots.length > 1 && snapshots[1].docs.isNotEmpty) {
          normalizedInvitees.add(snapshots[1].docs.first.id);
          continue;
        }

        throw Exception('No user found with email $identifier.');
      }

      normalizedInvitees.add(identifier);
    }

    for (final targetUid in normalizedInvitees.toSet()) {
      if (targetUid.isEmpty) continue;
      final inviteRef = firestore
          .collection(FirestorePaths.workspaceInvites)
          .doc('${workspaceId}_$targetUid');

      batch.set(inviteRef, {
        FirestorePaths.workspaceId: workspaceId,
        FirestorePaths.fromUid: currentUserId,
        FirestorePaths.toUid: targetUid,
        FirestorePaths.status: 'pending',
        FirestorePaths.timestamp: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  @override
  Future<void> leaveWorkspace({
    String? workspaceId,
    List<String>? importedBoardsToKeep,
  }) async {
    // Cloud Functions handles the source-based logic.
    // This repository method is kept for compatibility but delegates to cloud function via service.
    // The actual implementation is in leaveWorkspace.js (Cloud Function).
    throw UnimplementedError(
      'leaveWorkspace should be called via CloudFunctionsService. Use WorkspaceService.leaveWorkspace instead.',
    );
  }

  @override
  Future<void> removeMemberFromWorkspace({
    required String workspaceId,
    required String memberUid,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final firestore = _firestoreService.getInstance();
    final workspaceRef = firestore
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId);
    final memberRef = workspaceRef
        .collection(FirestorePaths.workspaceMembersSubcollection)
        .doc(memberUid);

    await firestore.runTransaction((transaction) async {
      final workspaceSnapshot = await transaction.get(workspaceRef);
      if (!workspaceSnapshot.exists) {
        return;
      }

      final data = workspaceSnapshot.data() ?? {};
      final ownerId = data[FirestorePaths.ownerId] as String?;
      if (ownerId != uid) {
        throw Exception('Only owner can remove members.');
      }
      if (ownerId == memberUid) {
        throw Exception('Cannot remove workspace owner.');
      }

      transaction.delete(memberRef);
      transaction.update(workspaceRef, {
        FirestorePaths.memberCount: FieldValue.increment(-1),
        FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Stream<List<WorkspaceInvite>> getIncomingWorkspaceInvites() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);

    return _firestoreService
        .collection(FirestorePaths.workspaceInvites)
        .where(FirestorePaths.toUid, isEqualTo: uid)
        .where(FirestorePaths.status, isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              return WorkspaceInvite(
                id: doc.id,
                workspaceId:
                    (data[FirestorePaths.workspaceId] as String?) ?? '',
                fromUid: (data[FirestorePaths.fromUid] as String?) ?? '',
                toUid: (data[FirestorePaths.toUid] as String?) ?? '',
                senderName:
                    (data[FirestorePaths.senderName] as String?) ??
                    (data[FirestorePaths.fromUid] as String?) ??
                    'InkLink User',
                senderPhotoUrl: data[FirestorePaths.senderPic] as String?,
                workspaceName:
                    (data[FirestorePaths.name] as String?) ?? 'Workspace',
                status: (data[FirestorePaths.status] as String?) ?? 'pending',
                timestamp:
                    (data[FirestorePaths.timestamp] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                acceptedAt:
                    (data[FirestorePaths.status] == 'accepted' &&
                        data['acceptedAt'] is Timestamp)
                    ? (data['acceptedAt'] as Timestamp).toDate()
                    : null,
                rejectedAt:
                    (data[FirestorePaths.status] == 'rejected' &&
                        data['rejectedAt'] is Timestamp)
                    ? (data['rejectedAt'] as Timestamp).toDate()
                    : null,
              );
            }).toList();
          } catch (e) {
            return [];
          }
        });
  }

  @override
  Future<void> acceptWorkspaceInvite(String inviteId) async {
    final firestore = _firestoreService.getInstance();
    final inviteRef = _firestoreService
        .collection(FirestorePaths.workspaceInvites)
        .doc(inviteId);

    final inviteSnapshot = await inviteRef.get();
    if (!inviteSnapshot.exists) return;

    final data = inviteSnapshot.data() ?? {};
    final workspaceId = data[FirestorePaths.workspaceId] as String?;
    final toUid = data[FirestorePaths.toUid] as String?;

    if (workspaceId == null || toUid == null) return;

    await firestore.runTransaction((transaction) async {
      transaction.update(inviteRef, {
        FirestorePaths.status: 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        firestore
            .collection(FirestorePaths.workspaces)
            .doc(workspaceId)
            .collection(FirestorePaths.workspaceMembersSubcollection)
            .doc(toUid),
        {
          FirestorePaths.uid: toUid,
          'role': 'member',
          FirestorePaths.status: 'active',
          'joinedAt': FieldValue.serverTimestamp(),
          FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
        },
      );

      transaction.update(
        firestore.collection(FirestorePaths.workspaces).doc(workspaceId),
        {
          FirestorePaths.memberCount: FieldValue.increment(1),
          FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        firestore.collection(FirestorePaths.users).doc(toUid),
        {
          FirestorePaths.workspaceIds: FieldValue.arrayUnion([workspaceId]),
          FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> rejectWorkspaceInvite(String inviteId) async {
    await _firestoreService
        .collection(FirestorePaths.workspaceInvites)
        .doc(inviteId)
        .update({
          FirestorePaths.status: 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> addBoardToWorkspace({
    required String workspaceId,
    required String boardId,
  }) async {
    final firestore = _firestoreService.getInstance();
    final workspaceRef = _firestoreService
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId);

    await firestore.runTransaction((transaction) async {
      transaction.set(
        workspaceRef
            .collection(FirestorePaths.workspaceBoardsSubcollection)
            .doc(boardId),
        {
          FirestorePaths.boardId: boardId,
          'visible': true,
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      transaction.update(workspaceRef, {
        FirestorePaths.boardCount: FieldValue.increment(1),
        FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<String> createBoardInWorkspace({
    required String workspaceId,
    required String title,
    String? description,
    String? visibility,
  }) async {
    // Cloud Functions handles the board creation with workspace-native tagging.
    // This repository method is kept for consistency but delegates to cloud function via service.
    throw UnimplementedError(
      'createBoardInWorkspace should be called via CloudFunctionsService. Use WorkspaceService.createBoardInWorkspace instead.',
    );
  }

  @override
  Future<void> removeBoardFromWorkspace({
    required String workspaceId,
    required String boardId,
  }) async {
    final firestore = _firestoreService.getInstance();
    final workspaceRef = _firestoreService
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId);

    await firestore.runTransaction((transaction) async {
      transaction.delete(
        workspaceRef
            .collection(FirestorePaths.workspaceBoardsSubcollection)
            .doc(boardId),
      );

      transaction.update(workspaceRef, {
        FirestorePaths.boardCount: FieldValue.increment(-1),
        FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> setWorkspaceBoardVisibility({
    required String workspaceId,
    required String boardId,
    required bool visible,
  }) async {
    await _firestoreService
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId)
        .collection(FirestorePaths.workspaceBoardsSubcollection)
        .doc(boardId)
        .update({'visible': visible});
  }

  Future<void> _reconcileWorkspaceListeners({
    required Iterable<String> workspaceIds,
  }) async {
    final currentUid = currentUserId;
    final activeWorkspaceIds = workspaceIds.toSet();

    _ownedWorkspaceIds = {};
    _memberWorkspaceIds = {};
    _ownedWorkspaceDocs.clear();
    _memberWorkspaceDocs.clear();

    if (activeWorkspaceIds.isEmpty) {
      await _pruneLocalWorkspaces(visibleWorkspaceIds: const <String>{});
      _emitWorkspaceStreams();
      return;
    }

    final docsById = await _fetchDocumentsByIdSet(
      collectionPath: FirestorePaths.workspaces,
      ids: activeWorkspaceIds.toList(growable: false),
    );

    for (final wsId in activeWorkspaceIds) {
      final data = docsById[wsId];
      if (data == null) {
        await _removeWorkspaceFromIsar(wsId);
        continue;
      }

      final isOwner =
          currentUid != null && data[FirestorePaths.ownerId] == currentUid;
      if (isOwner) {
        _ownedWorkspaceIds.add(wsId);
        _ownedWorkspaceDocs[wsId] = data;
        await _saveWorkspaceToIsar(wsId, data, 'owner');
      } else {
        _memberWorkspaceIds.add(wsId);
        _memberWorkspaceDocs[wsId] = data;
        await _saveWorkspaceToIsar(wsId, data, 'member');
      }
    }

    final visibleLocalWorkspaceIds = <String>{
      ..._ownedWorkspaceDocs.keys,
      ..._memberWorkspaceDocs.keys,
    };
    await _pruneLocalWorkspaces(visibleWorkspaceIds: visibleLocalWorkspaceIds);
    _emitWorkspaceStreams();
  }

  Workspace _mapFirestoreWorkspace(String wsId, Map<String, dynamic> data) {
    return Workspace(
      id: wsId,
      ownerId: (data[FirestorePaths.ownerId] as String?) ?? '',
      name: (data[FirestorePaths.name] as String?) ?? '',
      description: (data[FirestorePaths.description] as String?) ?? '',
      memberCount: (data[FirestorePaths.memberCount] as num?)?.toInt() ?? 0,
      boardCount: (data[FirestorePaths.boardCount] as num?)?.toInt() ?? 0,
      createdAt:
          (data[FirestorePaths.createdAt] as Timestamp?)?.toDate() ??
          DateTime.now(),
      updatedAt:
          (data[FirestorePaths.updatedAt] as Timestamp?)?.toDate() ??
          DateTime.now(),
      currentUserRole: data[FirestorePaths.ownerId] == currentUserId
          ? 'owner'
          : 'member',
    );
  }

  Future<void> _saveWorkspaceToIsar(
    String wsId,
    Map<String, dynamic> data,
    String role,
  ) async {
    try {
      final isar = (await _localDatabaseService.database);
      final existingWorkspace = await isar.localWorkspaces
          .filter()
          .workspaceIdEqualTo(wsId)
          .findFirst();

      final localWorkspace = existingWorkspace ?? LocalWorkspace()
        ..workspaceId = wsId
        ..ownerId = (data[FirestorePaths.ownerId] as String?) ?? ''
        ..name = (data[FirestorePaths.name] as String?) ?? ''
        ..description = (data[FirestorePaths.description] as String?) ?? ''
        ..memberCount = (data[FirestorePaths.memberCount] as num?)?.toInt() ?? 0
        ..boardCount = (data[FirestorePaths.boardCount] as num?)?.toInt() ?? 0
        ..createdAt =
            (data[FirestorePaths.createdAt] as Timestamp?)?.toDate() ??
            DateTime.now()
        ..updatedAt =
            (data[FirestorePaths.updatedAt] as Timestamp?)?.toDate() ??
            DateTime.now()
        ..currentUserRole = role
        ..isSynced = true;

      await isar.writeTxn(() async {
        await isar.localWorkspaces.put(localWorkspace);
      });
    } catch (e) {
      // Silently fail if Isar is not available
    }
  }

  Future<void> _removeWorkspaceFromIsar(String wsId) async {
    try {
      final isar = (await _localDatabaseService.database);
      await isar.writeTxn(() async {
        final workspaces = await isar.localWorkspaces
            .filter()
            .workspaceIdEqualTo(wsId)
            .findAll();
        if (workspaces.isNotEmpty) {
          await isar.localWorkspaces.deleteAll(
            workspaces.map((workspace) => workspace.id).toList(growable: false),
          );
        }
      });
    } catch (e) {
      // Silently fail if Isar is not available
    }
  }

  Future<void> _pruneLocalWorkspaces({
    required Set<String> visibleWorkspaceIds,
  }) async {
    try {
      final isar = await _localDatabaseService.database;
      final localWorkspaces = await isar.localWorkspaces.where().findAll();
      final toDelete = localWorkspaces
          .where(
            (workspace) => !visibleWorkspaceIds.contains(workspace.workspaceId),
          )
          .map((workspace) => workspace.id)
          .toList(growable: false);

      if (toDelete.isEmpty) {
        return;
      }

      await isar.writeTxn(() async {
        await isar.localWorkspaces.deleteAll(toDelete);
      });
    } catch (_) {
      // Keep local cache unchanged if pruning fails.
    }
  }
}
