import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inklink/core/utils/notification_preferences.dart';
import 'package:inklink/domain/services/notification/notification_service.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';

class _FakeNotificationService implements NotificationService {
  final controller = StreamController<List<Map<String, dynamic>>>.broadcast(
    sync: true,
  );

  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() => controller.stream;

  @override
  Future<void> deleteNotification(String notificationId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Given a resolved workspace invite, Then the inbox status updates',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = _FakeNotificationService();
      final bloc = NotificationsBloc(
        notificationService: service,
        notificationPreferences: NotificationPreferences(prefs: prefs),
      );
      addTearDown(() async {
        await bloc.close();
        await service.controller.close();
      });

      bloc.add(const NotificationsLoadRequested());
      await Future<void>.delayed(Duration.zero);
      service.controller.add([
        {
          'id': 'notification-1',
          'type': 'workspace_invite',
          'status': 'pending',
          'targetId': 'invite-1',
          'extraData': {'inviteId': 'invite-1', 'workspaceId': 'workspace-1'},
          'timestamp': DateTime.now(),
        },
      ]);

      final loaded =
          await bloc.stream.firstWhere((state) => state is NotificationsLoaded)
              as NotificationsLoaded;
      expect(loaded.notifications.single['status'], 'pending');

      bloc.add(
        const NotificationWorkspaceInviteResolved(
          inviteId: 'invite-1',
          status: 'accepted',
        ),
      );

      final resolved =
          await bloc.stream.firstWhere((state) {
                if (state is! NotificationsLoaded) return false;
                return state.notifications.single['status'] == 'accepted';
              })
              as NotificationsLoaded;

      expect(resolved.notifications.single['type'], 'workspace_invite');
      expect(resolved.notifications.single['targetId'], 'invite-1');
    },
  );
}
