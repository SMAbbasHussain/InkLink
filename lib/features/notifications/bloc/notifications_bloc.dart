import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/notification_preferences.dart';
import '../../../domain/repositories/notification/notification_repository.dart';

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

class NotificationGroup {
  final String key;
  final Map<String, dynamic> latestNotification;
  final List<Map<String, dynamic>> items;

  const NotificationGroup({
    required this.key,
    required this.latestNotification,
    required this.items,
  });

  int get count => items.length;
  bool get hasUnread => items.any((item) => item['isRead'] != true);
}

class NotificationsLoaded extends NotificationsState {
  final List<NotificationGroup> groups;

  const NotificationsLoaded(this.groups);
}

class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);
}

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationRepository _notificationRepository;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSub;
  Set<String> _readIds = <String>{};
  List<Map<String, dynamic>> _rawNotifications = <Map<String, dynamic>>[];

  NotificationsBloc({required NotificationRepository notificationRepository})
    : _notificationRepository = notificationRepository,
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
    _notificationsSub = _notificationRepository.watchNotifications().listen((
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
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in event.notifications) {
      final type = item['type']?.toString() ?? 'general';
      final fromUid = item['fromUid']?.toString() ?? 'system';
      final explicitGroup = item['groupingKey']?.toString();
      final key = explicitGroup ?? '$type:$fromUid:${_groupTargetId(item)}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final groups =
        grouped.entries.map((entry) {
          final items = entry.value;
          return NotificationGroup(
            key: entry.key,
            latestNotification: items.first,
            items: items,
          );
        }).toList()..sort((left, right) {
          return _timestampOf(
            right.latestNotification,
          ).compareTo(_timestampOf(left.latestNotification));
        });

    emit(NotificationsLoaded(groups));
  }

  Future<void> markNotificationRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    await NotificationPreferences.markAsRead(notificationId);
    _readIds.add(notificationId);
    if (_rawNotifications.isNotEmpty) {
      add(_NotificationsUpdated(_normalizeNotifications(_rawNotifications)));
    }
  }

  Future<void> _onDeleteRequested(
    NotificationsDeleteRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await _notificationRepository.deleteNotification(event.notificationId);
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

  String _groupTargetId(Map<String, dynamic> item) {
    final extraData = item['extraData'];
    if (extraData is Map) {
      final inviteId = extraData['inviteId']?.toString();
      if (inviteId != null && inviteId.isNotEmpty) return inviteId;

      final requestId = extraData['requestId']?.toString();
      if (requestId != null && requestId.isNotEmpty) return requestId;

      final boardId = extraData['boardId']?.toString();
      if (boardId != null && boardId.isNotEmpty) return boardId;
    }

    final targetId = item['targetId']?.toString();
    return targetId == null || targetId.isEmpty ? 'all' : targetId;
  }

  DateTime _timestampOf(Map<String, dynamic> item) {
    final raw = item['timestamp'];
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);

    final parsed = raw?.toString();
    if (parsed == null || parsed.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.tryParse(parsed) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Future<void> close() async {
    await _notificationsSub?.cancel();
    return super.close();
  }
}
