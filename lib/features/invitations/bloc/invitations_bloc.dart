import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/invitation/invitation_repository.dart';

abstract class InvitationsEvent {
  const InvitationsEvent();
}

class InvitationsLoadRequested extends InvitationsEvent {
  const InvitationsLoadRequested();
}

class InvitationAcceptRequested extends InvitationsEvent {
  final String inviteId;
  final String? boardId;

  const InvitationAcceptRequested(this.inviteId, {this.boardId});
}

class InvitationDeclineRequested extends InvitationsEvent {
  final String inviteId;

  const InvitationDeclineRequested(this.inviteId);
}

class _InvitationsUpdated extends InvitationsEvent {
  final List<Map<String, dynamic>> invites;

  const _InvitationsUpdated(this.invites);
}

abstract class InvitationsState {
  const InvitationsState();
}

class InvitationsInitial extends InvitationsState {
  const InvitationsInitial();
}

class InvitationsLoading extends InvitationsState {
  const InvitationsLoading();
}

class InvitationsLoaded extends InvitationsState {
  final List<Map<String, dynamic>> invites;
  final String? message;
  final bool isError;
  final String? openedBoardId;

  const InvitationsLoaded({
    required this.invites,
    this.message,
    this.isError = false,
    this.openedBoardId,
  });

  InvitationsLoaded copyWith({
    List<Map<String, dynamic>>? invites,
    Object? message = _unset,
    bool? isError,
    Object? openedBoardId = _unset,
  }) {
    return InvitationsLoaded(
      invites: invites ?? this.invites,
      message: message == _unset ? this.message : message as String?,
      isError: isError ?? this.isError,
      openedBoardId: openedBoardId == _unset
          ? this.openedBoardId
          : openedBoardId as String?,
    );
  }
}

class InvitationsError extends InvitationsState {
  final String message;

  const InvitationsError(this.message);
}

const Object _unset = Object();

class InvitationsBloc extends Bloc<InvitationsEvent, InvitationsState> {
  final InvitationRepository _invitationRepository;
  StreamSubscription<List<Map<String, dynamic>>>? _invitesSub;

  InvitationsBloc({required InvitationRepository invitationRepository})
    : _invitationRepository = invitationRepository,
      super(const InvitationsInitial()) {
    on<InvitationsLoadRequested>(_onLoadRequested);
    on<_InvitationsUpdated>(_onUpdated);
    on<InvitationAcceptRequested>(_onAcceptRequested);
    on<InvitationDeclineRequested>(_onDeclineRequested);
  }

  Future<void> _onLoadRequested(
    InvitationsLoadRequested event,
    Emitter<InvitationsState> emit,
  ) async {
    emit(const InvitationsLoading());
    await _invitesSub?.cancel();
    _invitesSub = _invitationRepository.watchPendingInvites().listen(
      (invites) => add(_InvitationsUpdated(invites)),
      onError: (error) => emit(InvitationsError(error.toString())),
    );
  }

  void _onUpdated(_InvitationsUpdated event, Emitter<InvitationsState> emit) {
    emit(InvitationsLoaded(invites: event.invites));
  }

  Future<void> _onAcceptRequested(
    InvitationAcceptRequested event,
    Emitter<InvitationsState> emit,
  ) async {
    try {
      await _invitationRepository.acceptInvite(event.inviteId);
      final current = state;
      if (current is InvitationsLoaded) {
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
      if (current is InvitationsLoaded) {
        emit(current.copyWith(message: e.toString(), isError: true));
      } else {
        emit(InvitationsError(e.toString()));
      }
    }
  }

  Future<void> _onDeclineRequested(
    InvitationDeclineRequested event,
    Emitter<InvitationsState> emit,
  ) async {
    try {
      await _invitationRepository.declineInvite(event.inviteId);
      final current = state;
      if (current is InvitationsLoaded) {
        emit(current.copyWith(message: 'Invite declined.', isError: false));
      }
    } catch (e) {
      final current = state;
      if (current is InvitationsLoaded) {
        emit(current.copyWith(message: e.toString(), isError: true));
      } else {
        emit(InvitationsError(e.toString()));
      }
    }
  }

  @override
  Future<void> close() async {
    await _invitesSub?.cancel();
    return super.close();
  }
}
