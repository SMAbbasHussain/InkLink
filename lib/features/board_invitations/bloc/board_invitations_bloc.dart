import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/invitation/invitation_repository.dart';

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

  const BoardInvitationsLoaded({
    required this.invites,
    this.message,
    this.isError = false,
    this.openedBoardId,
  });

  BoardInvitationsLoaded copyWith({
    List<Map<String, dynamic>>? invites,
    Object? message = _unset,
    bool? isError,
    Object? openedBoardId = _unset,
  }) {
    return BoardInvitationsLoaded(
      invites: invites ?? this.invites,
      message: message == _unset ? this.message : message as String?,
      isError: isError ?? this.isError,
      openedBoardId: openedBoardId == _unset
          ? this.openedBoardId
          : openedBoardId as String?,
    );
  }
}

class BoardInvitationsError extends BoardInvitationsState {
  final String message;

  const BoardInvitationsError(this.message);
}

const Object _unset = Object();

class BoardInvitationsBloc extends Bloc<BoardInvitationsEvent, BoardInvitationsState> {
  final InvitationRepository _invitationRepository;
  StreamSubscription<List<Map<String, dynamic>>>? _invitesSub;

  BoardInvitationsBloc({required InvitationRepository invitationRepository})
    : _invitationRepository = invitationRepository,
      super(const BoardInvitationsInitial()) {
    on<BoardInvitationsLoadRequested>(_onLoadRequested);
    on<_BoardInvitationsUpdated>(_onUpdated);
    on<BoardInvitationAcceptRequested>(_onAcceptRequested);
    on<BoardInvitationDeclineRequested>(_onDeclineRequested);
  }

  Future<void> _onLoadRequested(
    BoardInvitationsLoadRequested event,
    Emitter<BoardInvitationsState> emit,
  ) async {
    emit(const BoardInvitationsLoading());
    await _invitesSub?.cancel();
    _invitesSub = _invitationRepository.watchPendingInvites().listen(
      (invites) => add(_BoardInvitationsUpdated(invites)),
      onError: (error) => emit(BoardInvitationsError(error.toString())),
    );
  }

  void _onUpdated(_BoardInvitationsUpdated event, Emitter<BoardInvitationsState> emit) {
    emit(BoardInvitationsLoaded(invites: event.invites));
  }

  Future<void> _onAcceptRequested(
    BoardInvitationAcceptRequested event,
    Emitter<BoardInvitationsState> emit,
  ) async {
    try {
      await _invitationRepository.acceptInvite(event.inviteId);
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
      final current = state;
      if (current is BoardInvitationsLoaded) {
        emit(current.copyWith(message: e.toString(), isError: true));
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
      await _invitationRepository.declineInvite(event.inviteId);
      final current = state;
      if (current is BoardInvitationsLoaded) {
        emit(current.copyWith(message: 'Invite declined.', isError: false));
      }
    } catch (e) {
      final current = state;
      if (current is BoardInvitationsLoaded) {
        emit(current.copyWith(message: e.toString(), isError: true));
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
}

