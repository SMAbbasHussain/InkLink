import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/models/board.dart';
import '../../../domain/services/web_companion_service.dart';

class WebBoardsState {
  final List<Board> myBoards;
  final bool myBoardsLoading;
  final Object? myBoardsError;

  final List<Board> publicBoards;
  final bool publicBoardsLoading;
  final bool publicBoardsLoaded;
  final Object? publicBoardsError;

  const WebBoardsState({
    this.myBoards = const [],
    this.myBoardsLoading = true,
    this.myBoardsError,
    this.publicBoards = const [],
    this.publicBoardsLoading = false,
    this.publicBoardsLoaded = false,
    this.publicBoardsError,
  });

  WebBoardsState copyWith({
    List<Board>? myBoards,
    bool? myBoardsLoading,
    Object? Function()? myBoardsError,
    List<Board>? publicBoards,
    bool? publicBoardsLoading,
    bool? publicBoardsLoaded,
    Object? Function()? publicBoardsError,
  }) => WebBoardsState(
    myBoards: myBoards ?? this.myBoards,
    myBoardsLoading: myBoardsLoading ?? this.myBoardsLoading,
    myBoardsError: myBoardsError != null ? myBoardsError() : this.myBoardsError,
    publicBoards: publicBoards ?? this.publicBoards,
    publicBoardsLoading: publicBoardsLoading ?? this.publicBoardsLoading,
    publicBoardsLoaded: publicBoardsLoaded ?? this.publicBoardsLoaded,
    publicBoardsError: publicBoardsError != null
        ? publicBoardsError()
        : this.publicBoardsError,
  );
}

/// Manages the user's boards, public board discovery, and board lifecycle
/// operations for the web companion via [WebCompanionService].
class WebBoardsCubit extends Cubit<WebBoardsState> {
  final WebCompanionService _service;
  StreamSubscription<List<Board>>? _boardsSub;

  WebBoardsCubit({required this._service}) : super(const WebBoardsState()) {
    rebind();
  }

  void rebind() {
    _boardsSub?.cancel();
    emit(const WebBoardsState());
    _boardsSub = _service.watchMyBoards().listen(
      (boards) {
        if (!isClosed) {
          emit(
            state.copyWith(
              myBoards: boards,
              myBoardsLoading: false,
              myBoardsError: () => null,
            ),
          );
        }
      },
      onError: (Object error) {
        if (!isClosed) {
          emit(
            state.copyWith(myBoardsLoading: false, myBoardsError: () => error),
          );
        }
      },
    );
  }

  String? get currentUserId => _service.currentUser?.uid;

  Future<void> loadPublicBoards({bool force = false}) async {
    if (!force && (state.publicBoardsLoading || state.publicBoardsLoaded)) {
      return;
    }
    emit(
      state.copyWith(publicBoardsLoading: true, publicBoardsError: () => null),
    );
    try {
      final boards = await _service.loadPublicBoards();
      if (isClosed) return;
      emit(
        state.copyWith(
          publicBoards: boards,
          publicBoardsLoading: false,
          publicBoardsLoaded: true,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(publicBoardsLoading: false, publicBoardsError: () => e),
      );
    }
  }

  Future<String> createBoard({
    required String name,
    String visibility = Board.visibilityPrivate,
    String privateJoinPolicy = Board.policyOwnerOnlyInvite,
    String whoCanInvite = Board.inviteOwnerOnly,
    String defaultLinkJoinRole = Board.roleViewer,
    List<String> tags = const [],
    bool allowMembersToCopy = false,
  }) => _service.createBoard(
    name: name,
    visibility: visibility,
    privateJoinPolicy: privateJoinPolicy,
    whoCanInvite: whoCanInvite,
    defaultLinkJoinRole: defaultLinkJoinRole,
    tags: tags,
    allowMembersToCopy: allowMembersToCopy,
  );

  Future<void> joinBoard(String boardIdOrCode) =>
      _service.joinBoard(boardIdOrCode);

  Future<void> renameBoard(String boardId, String newName) =>
      _service.renameBoard(boardId, newName);

  Future<void> setBoardArchived(String boardId, {required bool archived}) =>
      _service.setBoardArchived(boardId, archived: archived);

  Future<void> setBoardPaused(String boardId, {required bool paused}) =>
      _service.setBoardPaused(boardId, paused: paused);

  Future<void> deleteBoard(String boardId) => _service.deleteBoard(boardId);

  Future<void> duplicateBoard(String boardId, {String? customTitle}) =>
      _service.duplicateBoard(boardId, customTitle: customTitle);

  Future<void> updateBoardTags(String boardId, List<String> tags) =>
      _service.updateBoardTags(boardId, tags);

  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    bool? allowMembersToCopy,
  }) => _service.updateBoardSettings(
    boardId: boardId,
    visibility: visibility,
    privateJoinPolicy: privateJoinPolicy,
    whoCanInvite: whoCanInvite,
    defaultLinkJoinRole: defaultLinkJoinRole,
    allowMembersToCopy: allowMembersToCopy,
  );

  @override
  Future<void> close() async {
    await _boardsSub?.cancel();
    return super.close();
  }
}
