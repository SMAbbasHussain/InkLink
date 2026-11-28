import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/notification/in_app_notification.dart';
import '../data/web_board_ops.dart';
import '../domain/web_companion_service.dart';

class WebNotificationsState {
  final List<InAppNotification> notifications;
  final bool loading;
  final Object? error;

  const WebNotificationsState({
    this.notifications = const [],
    this.loading = true,
    this.error,
  });

  int get unreadCount => unreadNotificationCount(notifications, const {});

  WebNotificationsState copyWith({
    List<InAppNotification>? notifications,
    bool? loading,
    Object? Function()? error,
  }) => WebNotificationsState(
    notifications: notifications ?? this.notifications,
    loading: loading ?? this.loading,
    error: error != null ? error() : this.error,
  );
}

/// Manages the web notification feed and browser read-state via
/// [WebCompanionService].
class WebNotificationsCubit extends Cubit<WebNotificationsState> {
  final WebCompanionService _service;
  StreamSubscription<List<InAppNotification>>? _sub;

  WebNotificationsCubit({required this._service})
    : super(const WebNotificationsState()) {
    rebind();
  }

  void rebind() {
    _sub?.cancel();
    emit(const WebNotificationsState());
    _sub = _service.watchNotificationsWithReadState().listen(
      (items) {
        if (!isClosed) {
          emit(
            state.copyWith(
              notifications: items,
              loading: false,
              error: () => null,
            ),
          );
        }
      },
      onError: (Object error) {
        if (!isClosed) {
          emit(state.copyWith(loading: false, error: () => error));
        }
      },
    );
  }

  Future<void> deleteNotification(String notificationId) =>
      _service.deleteNotification(notificationId);

  Future<void> markNotificationRead(String id) =>
      _service.markNotificationRead(id);

  Future<void> markAllNotificationsRead(Iterable<String> ids) =>
      _service.markAllNotificationsRead(ids);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
