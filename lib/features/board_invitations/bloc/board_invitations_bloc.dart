import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/app_error_formatter.dart';
import '../../../domain/services/invitation/invitation_service.dart';

abstract class BoardInvitationsEvent {
  const BoardInvitationsEvent();
}

class BoardInvitationsLoadRequested extends BoardInvitationsEvent {
  const BoardInvitationsLoadRequested();
}

typedef BoardInviteDecisionCallback =
    void Function(bool success, String? error);

class BoardInvitationAcceptRequested extends BoardInvitationsEvent {
  final String inviteId;
  final String? boardId;
  final BoardInviteDecisionCallback? onCompleted;

  const BoardInvitationAcceptRequested(
    this.inviteId, {
    this.boardId,
    this.onCompleted,
  });
}

class BoardInvitationDeclineRequested extends BoardInvitationsEvent {
  final String inviteId;
  final BoardInviteDecisionCallback? onCompleted;

  const BoardInvitationDeclineRequested(this.inviteId, {this.onCompleted});
}

class _BoardInvitationsUpdated extends BoardInvitationsEvent {
  final List<Map<String, dynamic>> invites;

  const _BoardInvitationsUpdated(this.invites);
}

class _BoardInvitationsStreamFailed extends BoardInvitationsEvent {
  final String message;

  const _BoardInvitationsStreamFailed(this.message);
}

abstract class BoardInvitationsState {
  const BoardInvitationsState();
}

class BoardInvitationsInitial extends BoardInvitationsState {
  const BoardInvitationsInitial();
}

class BoardInvitationsLoading extends BoardInvitationsState {
  const BoardInvitationsLoading();
}

class BoardInvitationsLoaded extends BoardInvitationsState {
  final List<Map<String, dynamic>> invites;
  final Set<String> processingInviteIds;
  final String? message;
  final bool isError;
  final String? openedBoardId;
  final bool isOffline;

  const BoardInvitationsLoaded({
    required this.invites,
    this.processingInviteIds = const <String>{},
    this.message,
    this.isError = false,
    this.openedBoardId,
    this.isOffline = false,
  });

  BoardInvitationsLoaded copyWith({
    List<Map<String, dynamic>>? invites,
    Set<String>? processingInviteIds,
    Object? message = _unset,
    bool? isError,
    Object? openedBoardId = _unset,
    bool? isOffline,
  }) {
    return BoardInvitationsLoaded(
      invites: invites ?? this.invites,
      processingInviteIds: processingInviteIds ?? this.processingInviteIds,
      message: message == _unset ? this.message : message as String?,
      isError: isError ?? this.isError,
      openedBoardId: openedBoardId == _unset
          ? this.openedBoardId
          : openedBoardId as String?,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class BoardInvitationsError extends BoardInvitationsState {
  final String message;

  const BoardInvitationsError(this.message);
}

const Object _unset = Object();

/// An invite hidden from the list while its accept/decline call is on the wire.
/// The original row and its position let a failed decision restore the tile.
class _OptimisticInvite {
  final Map<String, dynamic> invite;
  final int index;

  const _OptimisticInvite(this.invite, this.index);
}

class BoardInvitationsBloc
    extends Bloc<BoardInvitationsEvent, BoardInvitationsState> {
  final InvitationService _invitationService;
  StreamSubscription<List<Map<String, dynamic>>>? _invitesSub;
  final Set<String> _inFlightInviteIds = <String>{};
  final Map<String, _OptimisticInvite> _optimisticInvites =
      <String, _OptimisticInvite>{};
  bool _isOffline = false;

  BoardInvitationsBloc({required InvitationService invitationService})
    : _invitationService = invitationService,
      super(const BoardInvitationsInitial()) {
    on<BoardInvitationsLoadRequested>(_onLoadRequested);
    on<_BoardInvitationsUpdated>(_onUpdated);
    on<_BoardInvitationsStreamFailed>(_onStreamFailed);
    on<BoardInvitationAcceptRequested>(_onAcceptRequested);
    on<BoardInvitationDeclineRequested>(_onDeclineRequested);
  }

  Future<void> _onLoadRequested(
    BoardInvitationsLoadRequested event,
    Emitter<BoardInvitationsState> emit,
  ) async {
    emit(const BoardInvitationsLoading());
    await _invitesSub?.cancel();
    _isOffline = !(await _invitationService.isOnline());
    _invitesSub = _invitationService.watchPendingInvites().listen(
      (invites) {
        if (isClosed) return;
        add(_BoardInvitationsUpdated(invites));
      },
      onError: (error, stackTrace) {
        if (isClosed) return;
        developer.log(
          'BoardInvitationsBloc error: $error',
          name: 'BoardInvitationsBloc',
          stackTrace: stackTrace,
        );
        add(_BoardInvitationsStreamFailed(error.toString()));
      },
    );
  }

  void _onUpdated(
    _BoardInvitationsUpdated event,
    Emitter<BoardInvitationsState> emit,
  ) {
    emit(
      BoardInvitationsLoaded(
        invites: event.invites
            .where(
              (invite) => !_optimisticInvites.containsKey(
                invite['id']?.toString() ?? '',
              ),
            )
            .toList(growable: false),
        processingInviteIds: Set<String>.unmodifiable(_inFlightInviteIds),
        isOffline: _isOffline,
      ),
    );
  }

  void _onStreamFailed(
    _BoardInvitationsStreamFailed event,
    Emitter<BoardInvitationsState> emit,
  ) {
    emit(BoardInvitationsError(event.message));
  }

  /// Hides the invite right away and reports success, so the tile never waits
  /// for the Cloud Function's answer.
  void _hideInvite(
    String inviteId,
    Emitter<BoardInvitationsState> emit, {
    required String message,
    String? openedBoardId,
  }) {
    final current = state;
    if (current is! BoardInvitationsLoaded) return;
    final index = current.invites.indexWhere(
      (invite) => invite['id']?.toString() == inviteId,
    );
    _optimisticInvites[inviteId] = _OptimisticInvite(
      index >= 0
          ? current.invites[index]
          : <String, dynamic>{'id': inviteId},
      index < 0 ? 0 : index,
    );
    emit(
      current.copyWith(
        invites: current.invites
            .where((invite) => invite['id']?.toString() != inviteId)
            .toList(growable: false),
        processingInviteIds: const <String>{},
        message: message,
        isError: false,
        openedBoardId: openedBoardId,
      ),
    );
  }

  /// Puts a failed decision's invite back where it was and reports the error.
  void _restoreInvite(
    String inviteId,
    Emitter<BoardInvitationsState> emit,
    String message,
  ) {
    final removal = _optimisticInvites.remove(inviteId);
    final current = state;
    if (current is! BoardInvitationsLoaded) return;
    final invites = List<Map<String, dynamic>>.from(current.invites);
    if (removal != null &&
        !invites.any((invite) => invite['id']?.toString() == inviteId)) {
      invites.insert(
        removal.index.clamp(0, invites.length),
        removal.invite,
      );
    }
    emit(
      current.copyWith(
        invites: invites,
        processingInviteIds: const <String>{},
        message: message,
        isError: true,
        isOffline: _isOffline,
      ),
    );
  }

  Future<void> _onAcceptRequested(
    BoardInvitationAcceptRequested event,
    Emitter<BoardInvitationsState> emit,
  ) async {
    if (event.inviteId.isEmpty ||
        _inFlightInviteIds.contains(event.inviteId) ||
        _optimisticInvites.containsKey(event.inviteId)) {
      return;
    }

    _inFlightInviteIds.add(event.inviteId);
    final current = state;
    if (current is BoardInvitationsLoaded) {
      emit(
        current.copyWith(
          processingInviteIds: Set<String>.unmodifiable(_inFlightInviteIds),
        ),
      );
    }

    try {
      await _invitationService.acceptInvite(event.inviteId);
      _inFlightInviteIds.remove(event.inviteId);
      _hideInvite(
        event.inviteId,
        emit,
        message: 'Invite accepted.',
        openedBoardId: event.boardId,
      );
      _optimisticInvites.remove(event.inviteId);
      event.onCompleted?.call(true, null);
    } catch (e) {
      _inFlightInviteIds.remove(event.inviteId);
      if (_looksOffline(e)) {
        _isOffline = true;
      }
      final message = AppErrorFormatter.cleanMessage(e);
      final latest = state;
      if (latest is BoardInvitationsLoaded) {
        emit(
          latest.copyWith(
            processingInviteIds: Set<String>.unmodifiable(_inFlightInviteIds),
            message: message,
            isError: true,
            isOffline: _isOffline,
          ),
        );
      }
      event.onCompleted?.call(false, message);
    }
  }

  Future<void> _onDeclineRequested(
    BoardInvitationDeclineRequested event,
    Emitter<BoardInvitationsState> emit,
  ) async {
    if (event.inviteId.isEmpty ||
        _inFlightInviteIds.contains(event.inviteId) ||
        _optimisticInvites.containsKey(event.inviteId)) {
      return;
    }

    _hideInvite(event.inviteId, emit, message: 'Invite declined.');
    event.onCompleted?.call(true, null);

    try {
      await _invitationService.declineInvite(event.inviteId);
      _optimisticInvites.remove(event.inviteId);
    } catch (e) {
      if (_looksOffline(e)) {
        _isOffline = true;
      }
      final message = AppErrorFormatter.cleanMessage(e);
      _restoreInvite(event.inviteId, emit, message);
      event.onCompleted?.call(false, message);
    }
  }

  @override
  Future<void> close() async {
    await stopForLogout();
    return super.close();
  }

  bool _looksOffline(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('offline') || message.contains('connection error');
  }

  Future<void> stopForLogout() async {
    await _invitesSub?.cancel();
    _invitesSub = null;
    _inFlightInviteIds.clear();
    _optimisticInvites.clear();
    _isOffline = false;
  }
}
