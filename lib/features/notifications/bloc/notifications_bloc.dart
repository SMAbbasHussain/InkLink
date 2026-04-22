import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/notification_preferences.dart';
import '../../../domain/services/notification/notification_service.dart';

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

class _NotificationsUpdated extends NotificationsEvent {
  final List<Map<String, dynamic>> notifications;

  const _NotificationsUpdated(this.notifications);
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

  const NotificationsLoaded(this.notifications);
}

class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);
}

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationService _notificationService;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSub;
  Set<String> _readIds = <String>{};
  List<Map<String, dynamic>> _rawNotifications = <Map<String, dynamic>>[];

  NotificationsBloc({required NotificationService notificationService})
    : _notificationService = notificationService,
      super(const NotificationsInitial()) {
    on<NotificationsLoadRequested>(_onLoadRequested);
    on<_NotificationsUpdated>(_onNotificationsUpdated);
    on<NotificationsDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(
    NotificationsLoadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(const NotificationsLoading());
    await _notificationsSub?.cancel();
    _readIds = await NotificationPreferences.getReadNotificationIds();
    _notificationsSub = _notificationService.watchNotifications().listen((
      items,
    ) {
      _rawNotifications = items;
      final normalized = _normalizeNotifications(items);
      add(_NotificationsUpdated(normalized));
    }, onError: (error) => emit(NotificationsError(error.toString())));
  }

  void _onNotificationsUpdated(
    _NotificationsUpdated event,
    Emitter<NotificationsState> emit,
  ) {
    final sorted = List<Map<String, dynamic>>.from(
      event.notifications,
    )..sort((left, right) => _timestampOf(right).compareTo(_timestampOf(left)));

    emit(NotificationsLoaded(sorted));
  }

  Future<void> markNotificationRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    await NotificationPreferences.markAsRead(notificationId);
    _readIds.add(notificationId);
    if (_rawNotifications.isNotEmpty) {
      add(_NotificationsUpdated(_normalizeNotifications(_rawNotifications)));
    }
  }

  Future<void> markAllNotificationsRead() async {
    if (_rawNotifications.isEmpty) return;

    for (final item in _rawNotifications) {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty || _readIds.contains(id)) continue;
      await NotificationPreferences.markAsRead(id);
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
      await NotificationPreferences.remove(event.notificationId);
      _readIds.remove(event.notificationId);
      _rawNotifications.removeWhere(
        (item) => item['id']?.toString() == event.notificationId,
      );
      add(_NotificationsUpdated(_normalizeNotifications(_rawNotifications)));
    } catch (_) {
      emit(const NotificationsError('Failed to delete notification'));
    }
  }

  List<Map<String, dynamic>> _normalizeNotifications(
    List<Map<String, dynamic>> notifications,
  ) {
    return notifications
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
  }

  @override
  Future<void> close() async {
    await stopForLogout();
    return super.close();
  }
}
