import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/domain/services/invitation/invitation_service.dart';
import 'package:inklink/features/board_invitations/bloc/board_invitations_bloc.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

/// A tiny in-memory stand-in for the shared board backend.
///
/// It deliberately enforces membership on both subscribe and publish. The
/// invitee therefore cannot open or edit the board until the accept call has
/// actually granted access, which is the race this test is guarding against.
class _SharedBoard {
  final String boardId;
  final String ownerId;
  final Set<String> members = <String>{};
  final List<LocalCrdtUpdate> updates = <LocalCrdtUpdate>[];
  final Set<StreamController<List<LocalCrdtUpdate>>> _subscribers =
      <StreamController<List<LocalCrdtUpdate>>>{};
  int _nextVersion = 1;

  _SharedBoard({required this.boardId, required this.ownerId}) {
    members.add(ownerId);
  }

  bool hasAccess(String uid) => members.contains(uid);

  void acceptInvite(String uid) {
    members.add(uid);
  }

  void _requireAccess(String uid) {
    if (!hasAccess(uid)) {
      throw StateError('$uid is not a member of $boardId');
    }
  }

  Stream<List<LocalCrdtUpdate>> subscribe(String uid) {
    _requireAccess(uid);
    late StreamController<List<LocalCrdtUpdate>> controller;
    controller = StreamController<List<LocalCrdtUpdate>>(
      onListen: () {
        // Emit a batch immediately, even when it is empty. CanvasBloc uses
        // `.first` to rebuild its update-id map, so this also completes that
        // initial read when the board has no history yet.
        controller.add(List<LocalCrdtUpdate>.of(updates));
      },
      onCancel: () {
        _subscribers.remove(controller);
      },
    );
    _subscribers.add(controller);
    return controller.stream;
  }

  void publish(String uid, LocalCrdtUpdate update) {
    _requireAccess(uid);
    updates.add(update);
    for (final subscriber in List<StreamController<List<LocalCrdtUpdate>>>.of(
      _subscribers,
    )) {
      if (!subscriber.isClosed) {
        subscriber.add(<LocalCrdtUpdate>[update]);
      }
    }
  }

  int takeVersion() => _nextVersion++;

  Future<void> dispose() async {
    for (final subscriber in _subscribers.toList()) {
      _subscribers.remove(subscriber);
      if (!subscriber.isClosed) {
        await subscriber.close();
      }
    }
  }
}

class _ClientCanvasService implements CanvasService {
  final _SharedBoard _board;
  final String _uid;

  _ClientCanvasService(this._board, this._uid);

  @override
  bool get canSync => true;

  @override
  String? get currentClientId => _uid;

  @override
  Future<void> ensureBoardCached(String boardId) async {}

  @override
  Stream<Board?> watchBoardById(String boardId) {
    return Stream<Board?>.value(
      Board(
        id: boardId,
        title: 'Invite sync board',
        ownerId: _board.ownerId,
        members: _board.members.toList(growable: false),
        currentUserRole: _uid == _board.ownerId
            ? Board.roleOwner
            : Board.roleEditor,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
  }

  @override
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String boardId) {
    return _board.subscribe(_uid);
  }

  @override
  Stream<List<LocalCrdtUpdate>> listenToCanvasPreviews(String boardId) {
    return Stream<List<LocalCrdtUpdate>>.value(const <LocalCrdtUpdate>[]);
  }

  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
    String action = 'upsert',
  }) async {
    final update = LocalCrdtUpdate()
      ..updateId = updateId
      ..boardId = boardId
      ..elementId = elementId
      ..action = action
      ..payloadBase64 = base64Encode(payload)
      ..sourceClientId = _uid
      ..appliedAt = DateTime.now()
      ..version = _board.takeVersion()
      ..isSynced = true;
    _board.publish(_uid, update);
  }

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {}

  @override
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required Uint8List payload,
  }) async {}

  @override
  Future<void> stopCrdtRemoteSync(String boardId) async {}

  @override
  void setBoardSingleUserStatus(bool isSingleUser) {}

  @override
  Future<void> markCrdtUpdateDeleted(String updateId, bool isDeleted) async {}

  @override
  Future<LocalCrdtUpdate?> getElementCrdtUpdate({
    required String boardId,
    required String elementId,
  }) async => null;

  @override
  Future<void> updateCrdtUpdatePayload({
    required String boardId,
    required String updateId,
    required Uint8List payload,
  }) async {}
}

class _FakeInvitationService implements InvitationService {
  final _SharedBoard _board;
  final String _inviteeUid;
  final String _inviteId;
  final List<Map<String, dynamic>> _invites;

  _FakeInvitationService({
    required _SharedBoard board,
    required String inviteeUid,
    required String inviteId,
  }) : _board = board,
       _inviteeUid = inviteeUid,
       _inviteId = inviteId,
       _invites = [
         <String, dynamic>{
           'id': inviteId,
           'boardId': board.boardId,
           'boardTitle': 'Invite sync board',
           'senderName': 'Owner',
           'targetRole': Board.roleEditor,
         },
       ];

  @override
  Stream<List<Map<String, dynamic>>> watchPendingInvites() {
    return Stream<List<Map<String, dynamic>>>.value(
      _invites.map(Map<String, dynamic>.from).toList(growable: false),
    );
  }

  @override
  Future<bool> isOnline() async => true;

  @override
  Future<void> acceptInvite(String inviteId) async {
    expect(inviteId, _inviteId);
    // Grant membership before returning. The board must open immediately after
    // this future completes, so any missing access would fail in subscribe or
    // the first CRDT push below.
    _board.acceptInvite(_inviteeUid);
    _invites.removeWhere((invite) => invite['id'] == inviteId);
  }

  @override
  Future<void> declineInvite(String inviteId) async {
    _invites.removeWhere((invite) => invite['id'] == inviteId);
  }
}

Future<void> _waitFor(
  bool Function() condition,
  String description, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

CanvasBloc _canvasClient(_SharedBoard board, String uid) {
  return CanvasBloc(
    canvasService: _ClientCanvasService(board, uid),
    boardId: board.boardId,
    currentUserId: uid,
  );
}

void main() {
  test(
    'invitee accepts, opens immediately, and syncs both directions',
    () async {
      final board = _SharedBoard(boardId: 'board-1', ownerId: 'owner-1');
      addTearDown(board.dispose);

      final owner = _canvasClient(board, 'owner-1');
      addTearDown(owner.close);
      owner.add(const CanvasInitializeCrdt('board-1'));
      await _waitFor(
        () => owner.state.currentUserRole == Board.roleOwner,
        'the owner board to open',
      );

      // Existing board content: the invitee must receive this when their very
      // first board subscription happens after accepting the invite.
      owner.add(
        const CanvasAddShape(CanvasShapeType.square, Offset(40, 40)),
      );
      await _waitFor(
        () => owner.state.elements.length == 1 && board.updates.isNotEmpty,
        'the owner seed shape to publish',
      );
      final seedId = owner.state.elements.single.id;

      final invitations = _FakeInvitationService(
        board: board,
        inviteeUid: 'member-2',
        inviteId: 'invite-1',
      );
      final invitationsBloc = BoardInvitationsBloc(
        invitationService: invitations,
      );
      addTearDown(invitationsBloc.close);
      invitationsBloc.add(const BoardInvitationsLoadRequested());
      await _waitFor(
        () => invitationsBloc.state is BoardInvitationsLoaded,
        'the invite inbox to load',
      );

      final loaded = invitationsBloc.state as BoardInvitationsLoaded;
      expect(loaded.invites, hasLength(1));
      expect(board.hasAccess('member-2'), isFalse);

      invitationsBloc.add(
        const BoardInvitationAcceptRequested(
          'invite-1',
          boardId: 'board-1',
        ),
      );
      await _waitFor(
        () =>
            invitationsBloc.state is BoardInvitationsLoaded &&
            (invitationsBloc.state as BoardInvitationsLoaded).openedBoardId ==
                'board-1',
        'the accepted invite to open the board',
      );
      expect(board.hasAccess('member-2'), isTrue);

      // Open immediately, in the same flow as the navigation listener: no
      // retry, delay, or manual re-authentication before the first sync.
      final invitee = _canvasClient(board, 'member-2');
      addTearDown(invitee.close);
      invitee.add(const CanvasInitializeCrdt('board-1'));
      await _waitFor(
        () =>
            !invitee.state.isLoading &&
            invitee.state.elements.any((element) => element.id == seedId),
        'the invitee to open with the existing board',
      );
      expect(invitee.state.currentUserRole, Board.roleEditor);

      // Direction 1: invitee -> owner.
      invitee.add(
        const CanvasAddShape(CanvasShapeType.circle, Offset(120, 80)),
      );
      await _waitFor(
        () => invitee.state.elements.length == 2,
        'the invitee local shape',
      );
      final inviteeShape = invitee.state.elements.firstWhere(
        (element) => element.id != seedId,
      );
      await _waitFor(
        () => owner.state.elements.any(
          (element) => element.id == inviteeShape.id,
        ),
        'the owner to receive the invitee update',
      );

      // Direction 2: owner -> invitee.
      owner.add(
        const CanvasAddShape(CanvasShapeType.triangle, Offset(220, 140)),
      );
      await _waitFor(
        () => owner.state.elements.length == 3,
        'the owner local shape',
      );
      final ownerShape = owner.state.elements.firstWhere(
        (element) =>
            element.id != seedId && element.id != inviteeShape.id,
      );
      await _waitFor(
        () => invitee.state.elements.any(
          (element) => element.id == ownerShape.id,
        ),
        'the invitee to receive the owner update',
      );

      expect(
        invitee.state.elements.map((element) => element.id).toSet(),
        owner.state.elements.map((element) => element.id).toSet(),
      );
      expect(
        board.updates.any((update) => update.sourceClientId == 'member-2'),
        isTrue,
      );
      expect(
        board.updates.any((update) => update.sourceClientId == 'owner-1'),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
