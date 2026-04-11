import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/invitation/invitation_service.dart';

abstract class BoardInvitationsEvent {
  const BoardInvitationsEvent();
}

class BoardInvitationsLoadRequested extends BoardInvitationsEvent {
  const BoardInvitationsLoadRequested();
}

class BoardInvitationAcceptRequested extends BoardInvitationsEvent {
  final String inviteId;
  final String? boardId;

  const BoardInvitationAcceptRequested(this.inviteId, {this.boardId});
}

class BoardInvitationDeclineRequested extends BoardInvitationsEvent {
  final String inviteId;

  const BoardInvitationDeclineRequested(this.inviteId);
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
  final String? message;
  final bool isError;
  final String? openedBoardId;
  final bool isOffline;

  const BoardInvitationsLoaded({
    required this.invites,
    this.message,
    this.isError = false,
    this.openedBoardId,
    this.isOffline = false,
  });

  BoardInvitationsLoaded copyWith({
    List<Map<String, dynamic>>? invites,
    Object? message = _unset,
    bool? isError,
    Object? openedBoardId = _unset,
    bool? isOffline,
  }) {
    return BoardInvitationsLoaded(
      invites: invites ?? this.invites,
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

class BoardInvitationsBloc
    extends Bloc<BoardInvitationsEvent, BoardInvitationsState> {
  final InvitationService _invitationService;
  StreamSubscription<List<Map<String, dynamic>>>? _invitesSub;
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
    emit(BoardInvitationsLoaded(invites: event.invites, isOffline: _isOffline));
  }

  void _onStreamFailed(
    _BoardInvitationsStreamFailed event,
    Emitter<BoardInvitationsState> emit,
  ) {
    emit(BoardInvitationsError(event.message));
  }

  Future<void> _onAcceptRequested(
    BoardInvitationAcceptRequested event,
    Emitter<BoardInvitationsState> emit,
  ) async {
    try {
      await _invitationService.acceptInvite(event.inviteId);
      final current = state;
      if (current is BoardInvitationsLoaded) {
        emit(
          current.copyWith(
            message: 'Invite accepted.',
            isError: false,
            openedBoardId: event.boardId,
          ),
        );
      }
    } catch (e) {
      if (_looksOffline(e)) {
        _isOffline = true;
      }
      final current = state;
      if (current is BoardInvitationsLoaded) {
        emit(
          current.copyWith(
            message: e.toString(),
            isError: true,
            isOffline: _isOffline,
          ),
        );
      } else {
        emit(BoardInvitationsError(e.toString()));
      }
    }
  }

  Future<void> _onDeclineRequested(
    BoardInvitationDeclineRequested event,
    Emitter<BoardInvitationsState> emit,
  ) async {
    try {
      await _invitationService.declineInvite(event.inviteId);
      final current = state;
      if (current is BoardInvitationsLoaded) {
        emit(current.copyWith(message: 'Invite declined.', isError: false));
      }
    } catch (e) {
      if (_looksOffline(e)) {
        _isOffline = true;
      }
      final current = state;
      if (current is BoardInvitationsLoaded) {
        emit(
          current.copyWith(
            message: e.toString(),
            isError: true,
            isOffline: _isOffline,
          ),
        );
      } else {
        emit(BoardInvitationsError(e.toString()));
      }
    }
  }

  @override
  Future<void> close() async {
    await _invitesSub?.cancel();
    return super.close();
  }

  bool _looksOffline(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('offline') || message.contains('connection error');
  }
}
