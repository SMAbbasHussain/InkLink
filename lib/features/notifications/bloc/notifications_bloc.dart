import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/notification_preferences.dart';
import '../../../domain/services/board/board_service.dart';
import '../../../domain/services/notification/notification_service.dart';
import '../../../core/utils/app_error_formatter.dart';

abstract class NotificationsEvent {
  const NotificationsEvent();
}

class NotificationsLoadRequested extends NotificationsEvent {
  const NotificationsLoadRequested();
}

class NotificationsDeleteRequested extends NotificationsEvent {
  final String notificationId;

  const NotificationsDeleteRequested(this.notificationId);
}

typedef AccessRequestDecisionCallback =
    void Function(bool success, String? error);

class NotificationRespondToAccessRequest extends NotificationsEvent {
  final String notificationId;
  final String boardId;
  final String requesterUid;
  final String action;
  final String requestType;
  final AccessRequestDecisionCallback? onCompleted;

  const NotificationRespondToAccessRequest({
    required this.notificationId,
    required this.boardId,
    required this.requesterUid,
    required this.action,
    required this.requestType,
    this.onCompleted,
  });
}

class NotificationMarkReadRequested extends NotificationsEvent {
  final String notificationId;

  const NotificationMarkReadRequested(this.notificationId);
}

/// Optimistically resolves a workspace invitation notification after the
/// workspace invitation has been accepted or declined.
class NotificationWorkspaceInviteResolved extends NotificationsEvent {
  final String inviteId;
  final String status;

  const NotificationWorkspaceInviteResolved({
    required this.inviteId,
    required this.status,
  });
}

class _NotificationsUpdated extends NotificationsEvent {
  final List<Map<String, dynamic>> notifications;

  const _NotificationsUpdated(this.notifications);
}

class _NotificationsErrorOccurred extends NotificationsEvent {
  final String error;

  const _NotificationsErrorOccurred(this.error);
}

abstract class NotificationsState {
  const NotificationsState();
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsState {
  final List<Map<String, dynamic>> notifications;
  final Set<String> processingAccessRequestIds;

  const NotificationsLoaded(
    this.notifications, {
    this.processingAccessRequestIds = const <String>{},
  });
}

class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);
}

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationService _notificationService;
  final NotificationPreferences _notificationPreferences;
  final BoardService? _boardService;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSub;
  Set<String> _readIds = <String>{};
  List<Map<String, dynamic>> _rawNotifications = <Map<String, dynamic>>[];
  final Set<String> _inFlightAccessRequestIds = <String>{};

  NotificationsBloc({
    required NotificationService notificationService,
    required NotificationPreferences notificationPreferences,
    BoardService? boardService,
  }) : _notificationService = notificationService,
       _notificationPreferences = notificationPreferences,
       _boardService = boardService,
       super(const NotificationsInitial()) {
    on<NotificationsLoadRequested>(_onLoadRequested);
    on<_NotificationsUpdated>(_onNotificationsUpdated);
    on<_NotificationsErrorOccurred>(_onErrorOccurred);
    on<NotificationsDeleteRequested>(_onDeleteRequested);
    on<NotificationRespondToAccessRequest>(_onRespondToAccessRequest);
    on<NotificationMarkReadRequested>(_onMarkReadRequested);
    on<NotificationWorkspaceInviteResolved>(_onWorkspaceInviteResolved);
  }

  Future<void> _onLoadRequested(
    NotificationsLoadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(const NotificationsLoading());
    await _notificationsSub?.cancel();
    _readIds = await _notificationPreferences.getReadNotificationIds();
    _notificationsSub = _notificationService.watchNotifications().listen(
      (items) {
        _rawNotifications = items;
        final normalized = _normalizeNotifications(items);
        add(_NotificationsUpdated(normalized));
      },
      onError: (error) => add(
        _NotificationsErrorOccurred(AppErrorFormatter.cleanMessage(error)),
      ),
    );
  }

  void _onNotificationsUpdated(
    _NotificationsUpdated event,
    Emitter<NotificationsState> emit,
  ) {
    final sorted = List<Map<String, dynamic>>.from(
      event.notifications,
    )..sort((left, right) => _timestampOf(right).compareTo(_timestampOf(left)));

    emit(
      NotificationsLoaded(
        sorted,
        processingAccessRequestIds: Set<String>.unmodifiable(
          _inFlightAccessRequestIds,
        ),
      ),
    );
  }

  void _onErrorOccurred(
    _NotificationsErrorOccurred event,
    Emitter<NotificationsState> emit,
  ) {
    emit(NotificationsError(event.error));
  }

  Future<void> _onMarkReadRequested(
    NotificationMarkReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    await markNotificationRead(event.notificationId);
  }

  Future<void> markNotificationRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    await _notificationPreferences.markAsRead(notificationId);
    _readIds.add(notificationId);
    if (_rawNotifications.isNotEmpty) {
      add(_NotificationsUpdated(_normalizeNotifications(_rawNotifications)));
    }
  }

  void _onWorkspaceInviteResolved(
    NotificationWorkspaceInviteResolved event,
    Emitter<NotificationsState> emit,
  ) {
    if (event.inviteId.isEmpty) return;
    var changed = false;
    _rawNotifications = _rawNotifications
        .map((item) {
          if (item['type'] != 'workspace_invite') return item;
          final extraData = item['extraData'];
          final inviteId = extraData is Map
              ? extraData['inviteId']?.toString()
              : null;
          if (inviteId != event.inviteId &&
              item['targetId']?.toString() != event.inviteId) {
            return item;
          }
          changed = true;
          return {...item, 'status': event.status};
        })
        .toList(growable: false);
    if (changed) {
      add(_NotificationsUpdated(_normalizeNotifications(_rawNotifications)));
    }
  }

  Future<void> markAllNotificationsRead() async {
    if (_rawNotifications.isEmpty) return;

    for (final item in _rawNotifications) {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty || _readIds.contains(id)) continue;
      await _notificationPreferences.markAsRead(id);
      _readIds.add(id);
    }

    add(_NotificationsUpdated(_normalizeNotifications(_rawNotifications)));
  }

  Future<void> _onDeleteRequested(
    NotificationsDeleteRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await _notificationService.deleteNotification(event.notificationId);
      await _notificationPreferences.remove(event.notificationId);
      _readIds.remove(event.notificationId);
      _rawNotifications.removeWhere(
        (item) => item['id']?.toString() == event.notificationId,
      );
      add(_NotificationsUpdated(_normalizeNotifications(_rawNotifications)));
    } catch (_) {
      emit(const NotificationsError('Failed to delete notification'));
    }
  }

  Future<void> _onRespondToAccessRequest(
    NotificationRespondToAccessRequest event,
    Emitter<NotificationsState> emit,
  ) async {
    if (event.notificationId.isEmpty ||
        _inFlightAccessRequestIds.contains(event.notificationId)) {
      return;
    }

    final boardService = _boardService;
    if (boardService == null) {
      event.onCompleted?.call(false, 'Board service is unavailable.');
      return;
    }

    _inFlightAccessRequestIds.add(event.notificationId);
    final before = state;
    if (before is NotificationsLoaded) {
      emit(
        NotificationsLoaded(
          before.notifications,
          processingAccessRequestIds: Set<String>.unmodifiable(
            _inFlightAccessRequestIds,
          ),
        ),
      );
    }

    try {
      await boardService.respondToBoardAccessRequest(
        boardId: event.boardId,
        requesterUid: event.requesterUid,
        notificationId: event.notificationId,
        action: event.action,
        requestType: event.requestType,
      );

      _inFlightAccessRequestIds.remove(event.notificationId);
      final updatedRaw = _rawNotifications.map((item) {
        if (item['id']?.toString() == event.notificationId) {
          return {
            ...item,
            'status': event.action == 'accept' ? 'accepted' : 'declined',
          };
        }
        return item;
      }).toList();
      _rawNotifications = updatedRaw;
      final normalized = _normalizeNotifications(_rawNotifications);
      final sorted = List<Map<String, dynamic>>.from(normalized)
        ..sort(
          (left, right) => _timestampOf(right).compareTo(_timestampOf(left)),
        );
      emit(
        NotificationsLoaded(
          sorted,
          processingAccessRequestIds: Set<String>.unmodifiable(
            _inFlightAccessRequestIds,
          ),
        ),
      );
      event.onCompleted?.call(true, null);
    } catch (e) {
      _inFlightAccessRequestIds.remove(event.notificationId);
      final cleanError = AppErrorFormatter.cleanMessage(e);
      final current = state;
      if (current is NotificationsLoaded) {
        emit(
          NotificationsLoaded(
            current.notifications,
            processingAccessRequestIds: Set<String>.unmodifiable(
              _inFlightAccessRequestIds,
            ),
          ),
        );
      } else {
        emit(NotificationsError('Failed to process request: $cleanError'));
      }
      event.onCompleted?.call(false, cleanError);
    }
  }

  List<Map<String, dynamic>> _normalizeNotifications(
    List<Map<String, dynamic>> notifications,
  ) {
    return notifications
        .where((item) => item['type'] != 'chat_message')
        .map(
          (item) => {
            ...item,
            'isRead': _readIds.contains(item['id']?.toString()),
          },
        )
        .toList(growable: false);
  }

  DateTime _timestampOf(Map<String, dynamic> item) {
    final raw = item['timestamp'];
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());

    try {
      final millis = (raw as dynamic).millisecondsSinceEpoch;
      if (millis is int) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
      if (millis is num) {
        return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
      }
    } catch (_) {}

    final parsed = raw?.toString();
    if (parsed == null || parsed.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.tryParse(parsed) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> stopForLogout() async {
    await _notificationsSub?.cancel();
    _notificationsSub = null;
    _readIds = <String>{};
    _rawNotifications = <Map<String, dynamic>>[];
    _inFlightAccessRequestIds.clear();
  }

  @override
  Future<void> close() async {
    await stopForLogout();
    return super.close();
  }
}
