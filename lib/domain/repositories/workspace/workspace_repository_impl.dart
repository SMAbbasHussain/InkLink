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
import '../../models/workspace.dart';
import 'workspace_repository.dart';

class FirestoreWorkspaceRepository implements WorkspaceRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final LocalDatabaseService _localDatabaseService;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userWorkspaceSub;
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _ownedWorkspaceDocSubs = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _memberWorkspaceDocSubs = {};
  String? _syncUserId;
  Set<String> _ownedWorkspaceIds = {};
  Set<String> _memberWorkspaceIds = {};
  final Map<String, Map<String, dynamic>> _ownedWorkspaceDocs = {};
  final Map<String, Map<String, dynamic>> _memberWorkspaceDocs = {};

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

    // Listen to user document for workspaceIds array
    _userWorkspaceSub = _firestoreService
        .collection(FirestorePaths.users)
        .doc(uid)
        .snapshots()
        .listen(
          (userSnapshot) async {
            try {
              if (!userSnapshot.exists) {
                await _reconcileWorkspaceListeners(ownedIds: {}, memberIds: {});
                return;
              }

              final userData = userSnapshot.data() ?? {};
              final workspaceIds =
                  (userData[FirestorePaths.workspaceIds] as List<dynamic>?)
                      ?.cast<String>() ??
                  [];

              // If no workspaceIds, no workspaces to sync
              if (workspaceIds.isEmpty) {
                await _reconcileWorkspaceListeners(ownedIds: {}, memberIds: {});
                return;
              }

              try {
                // Read each workspace individually (collection queries not allowed by rules)
                final ownedIds = <String>{};
                final memberIds = <String>{};

                for (final wsId in workspaceIds) {
                  try {
                    final wsDoc = await _firestoreService
                        .collection(FirestorePaths.workspaces)
                        .doc(wsId)
                        .get();

                    if (wsDoc.exists) {
                      final data = wsDoc.data() ?? {};
                      if (data[FirestorePaths.ownerId] == uid) {
                        ownedIds.add(wsId);
                      } else {
                        memberIds.add(wsId);
                      }
                    }
                  } catch (e) {
                    // Skip workspaces user doesn't have access to
                    continue;
                  }
                }

                await _reconcileWorkspaceListeners(
                  ownedIds: ownedIds,
                  memberIds: memberIds,
                );
              } catch (e) {
                // Handle permission errors gracefully - reconcile with empty to show local cache
                await _reconcileWorkspaceListeners(ownedIds: {}, memberIds: {});
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
    for (final sub in _ownedWorkspaceDocSubs.values) {
      await sub.cancel();
    }
    for (final sub in _memberWorkspaceDocSubs.values) {
      await sub.cancel();
    }
    _ownedWorkspaceDocSubs.clear();
    _memberWorkspaceDocSubs.clear();
    _ownedWorkspaceDocs.clear();
    _memberWorkspaceDocs.clear();
    _syncUserId = null;
    _ownedWorkspaceIds = {};
    _memberWorkspaceIds = {};
  }

  @override
  Stream<List<Workspace>> getOwnedWorkspaces() {
    return (() async* {
      // Emit initial value first
      yield _ownedWorkspaceDocs.entries
          .map((entry) => _mapFirestoreWorkspace(entry.key, entry.value))
          .toList();
      // Then periodically emit updates
      await for (final _ in Stream.periodic(
        const Duration(milliseconds: 500),
      )) {
        yield _ownedWorkspaceDocs.entries
            .map((entry) => _mapFirestoreWorkspace(entry.key, entry.value))
            .toList();
      }
    })();
  }

  @override
  Stream<List<Workspace>> getMemberWorkspaces() {
    return (() async* {
      // Emit initial value first
      yield _memberWorkspaceDocs.entries
          .map((entry) => _mapFirestoreWorkspace(entry.key, entry.value))
          .toList();
      // Then periodically emit updates
      await for (final _ in Stream.periodic(
        const Duration(milliseconds: 500),
      )) {
        yield _memberWorkspaceDocs.entries
            .map((entry) => _mapFirestoreWorkspace(entry.key, entry.value))
            .toList();
      }
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

  @override
  Stream<List<Board>> getWorkspaceBoards(String workspaceId, {int? limit}) {
    return _firestoreService
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId)
        .collection(FirestorePaths.workspaceBoardsSubcollection)
        .snapshots()
        .asyncMap((snapshot) async {
          final currentUid = currentUserId;
          final isar = await _localDatabaseService.database;
          final localBoards = await isar.localBoards.where().anyId().findAll();
          final localPreviewByBoardId = {
            for (final localBoard in localBoards)
              localBoard.boardId: localBoard.previewPath,
          };
          final boards = <Board>[];
          final visibleLinks = snapshot.docs.where((doc) {
            final data = doc.data();
            if (!data.containsKey('visible')) {
              return true;
            }
            return data['visible'] == true;
          });

          for (final linkDoc in visibleLinks) {
            final linkData = linkDoc.data();
            final linkedBoardId =
                (linkData[FirestorePaths.boardId] as String?) ?? linkDoc.id;
            try {
              final boardSnapshot = await _firestoreService
                  .collection(FirestorePaths.boards)
                  .doc(linkedBoardId)
                  .get();
              if (!boardSnapshot.exists) {
                continue;
              }
              final boardData = boardSnapshot.data() ?? {};
              boardData['currentUserRole'] =
                  boardData[FirestorePaths.ownerId] == currentUid
                  ? Board.roleOwner
                  : Board.roleViewer;
              final firestoreBoard = Board.fromMap(boardData, linkedBoardId);
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
            } catch (_) {
              // Skip boards not readable by current user.
              continue;
            }
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
          final members = <WorkspaceMember>[];
          for (final memberDoc in snapshot.docs) {
            final memberData = memberDoc.data();
            final uid =
                (memberData[FirestorePaths.uid] as String?) ?? memberDoc.id;
            String? displayName;
            String? email;
            String? photoUrl;

            try {
              final userSnapshot = await _firestoreService
                  .collection(FirestorePaths.users)
                  .doc(uid)
                  .get();
              if (userSnapshot.exists) {
                final userData = userSnapshot.data() ?? {};
                displayName = userData[FirestorePaths.displayName] as String?;
                email = userData[FirestorePaths.email] as String?;
                photoUrl = userData[FirestorePaths.photoURL] as String?;
              }
            } catch (_) {
              // Member list should still render even if user profile read fails.
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
        final emailSnapshot = await firestore
            .collection(FirestorePaths.users)
            .where(FirestorePaths.email, isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (emailSnapshot.docs.isNotEmpty) {
          normalizedInvitees.add(emailSnapshot.docs.first.id);
          continue;
        }

        final fallbackSnapshot = await firestore
            .collection(FirestorePaths.users)
            .where(FirestorePaths.email, isEqualTo: identifier)
            .limit(1)
            .get();
        if (fallbackSnapshot.docs.isNotEmpty) {
          normalizedInvitees.add(fallbackSnapshot.docs.first.id);
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
  Future<void> leaveWorkspace(String workspaceId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final firestore = _firestoreService.getInstance();
    final workspaceRef = firestore
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId);
    final memberRef = workspaceRef
        .collection(FirestorePaths.workspaceMembersSubcollection)
        .doc(uid);

    await firestore.runTransaction((transaction) async {
      final workspaceSnapshot = await transaction.get(workspaceRef);
      if (!workspaceSnapshot.exists) {
        return;
      }

      final data = workspaceSnapshot.data() ?? {};
      if (data[FirestorePaths.ownerId] == uid) {
        throw Exception('Owner cannot leave workspace.');
      }

      transaction.delete(memberRef);
      transaction.update(workspaceRef, {
        FirestorePaths.memberCount: FieldValue.increment(-1),
        FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(firestore.collection(FirestorePaths.users).doc(uid), {
        FirestorePaths.workspaceIds: FieldValue.arrayRemove([workspaceId]),
      });
    });
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
    required Set<String> ownedIds,
    required Set<String> memberIds,
  }) async {
    _ownedWorkspaceIds = ownedIds;
    _memberWorkspaceIds = memberIds;

    // Remove stale owned listeners
    final staleOwned = _ownedWorkspaceDocSubs.keys
        .where((id) => !ownedIds.contains(id))
        .toList();
    for (final id in staleOwned) {
      await _ownedWorkspaceDocSubs.remove(id)?.cancel();
      _ownedWorkspaceDocs.remove(id);
    }

    // Add new owned listeners
    for (final wsId in ownedIds) {
      if (_ownedWorkspaceDocSubs.containsKey(wsId)) continue;
      _ownedWorkspaceDocSubs[wsId] = _firestoreService
          .collection(FirestorePaths.workspaces)
          .doc(wsId)
          .snapshots()
          .listen(
            (doc) async {
              try {
                if (doc.exists) {
                  _ownedWorkspaceDocs[wsId] = doc.data() ?? {};
                  // Save to Isar
                  await _saveWorkspaceToIsar(wsId, doc.data() ?? {}, 'owner');
                } else {
                  _ownedWorkspaceDocs.remove(wsId);
                  _ownedWorkspaceIds.remove(wsId);
                  // Remove from Isar
                  await _removeWorkspaceFromIsar(wsId);
                }
              } catch (e) {
                // Silent fail on listener errors
              }
            },
            onError: (error) {
              // Silently handle listener errors
            },
          );
    }

    // Remove stale member listeners
    final staleMember = _memberWorkspaceDocSubs.keys
        .where((id) => !memberIds.contains(id))
        .toList();
    for (final id in staleMember) {
      await _memberWorkspaceDocSubs.remove(id)?.cancel();
      _memberWorkspaceDocs.remove(id);
    }

    // Add new member listeners
    for (final wsId in memberIds) {
      if (_memberWorkspaceDocSubs.containsKey(wsId)) continue;
      _memberWorkspaceDocSubs[wsId] = _firestoreService
          .collection(FirestorePaths.workspaces)
          .doc(wsId)
          .snapshots()
          .listen(
            (doc) async {
              try {
                if (doc.exists) {
                  _memberWorkspaceDocs[wsId] = doc.data() ?? {};
                  // Save to Isar
                  await _saveWorkspaceToIsar(wsId, doc.data() ?? {}, 'member');
                } else {
                  _memberWorkspaceDocs.remove(wsId);
                  _memberWorkspaceIds.remove(wsId);
                  // Remove from Isar
                  await _removeWorkspaceFromIsar(wsId);
                }
              } catch (e) {
                // Silent fail on listener errors
              }
            },
            onError: (error) {
              // Silently handle listener errors
            },
          );
    }
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

      final localWorkspace = LocalWorkspace()
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
        // Query all workspaces and find the one to delete
        final allWorkspaces = await isar.localWorkspaces.where().findAll();
        final toDelete = allWorkspaces
            .where((ws) => ws.workspaceId == wsId)
            .map((ws) => ws.id)
            .toList();
        if (toDelete.isNotEmpty) {
          await isar.localWorkspaces.deleteAll(toDelete);
        }
      });
    } catch (e) {
      // Silently fail if Isar is not available
    }
  }
}
