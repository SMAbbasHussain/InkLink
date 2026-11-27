import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inklink/core/utils/notification_preferences.dart';
import 'package:inklink/domain/services/board/board_service.dart';
import 'package:inklink/domain/services/notification/notification_service.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';

class _FakeBoardService extends Fake implements BoardService {
  int respondCalls = 0;
  Completer<void>? gate;

  @override
  Future<void> respondToBoardAccessRequest({
    required String boardId,
    required String requesterUid,
    required String notificationId,
    required String action,
    required String requestType,
  }) async {
    respondCalls++;
    if (gate != null) {
      await gate!.future;
    }
  }
}

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

  test(
    'ignores rapid duplicate NotificationRespondToAccessRequest events while in flight',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = _FakeNotificationService();
      final gate = Completer<void>();
      final boardService = _FakeBoardService()..gate = gate;
      final bloc = NotificationsBloc(
        notificationService: service,
        notificationPreferences: NotificationPreferences(prefs: prefs),
        boardService: boardService,
      );
      addTearDown(() async {
        await bloc.close();
        await service.controller.close();
      });

      bloc.add(const NotificationsLoadRequested());
      await Future<void>.delayed(Duration.zero);
      service.controller.add([
        {
          'id': 'notif-1',
          'type': 'board_edit_request',
          'status': 'pending',
          'targetId': 'board-1',
          'extraData': {
            'boardId': 'board-1',
            'requesterUid': 'user-2',
            'requestType': 'edit',
          },
          'timestamp': DateTime.now(),
        },
      ]);
      await bloc.stream.firstWhere((s) => s is NotificationsLoaded);

      final firstDone = Completer<bool>();
      bloc.add(
        NotificationRespondToAccessRequest(
          notificationId: 'notif-1',
          boardId: 'board-1',
          requesterUid: 'user-2',
          action: 'accept',
          requestType: 'edit',
          onCompleted: (ok, _) => firstDone.complete(ok),
        ),
      );
      bloc.add(
        const NotificationRespondToAccessRequest(
          notificationId: 'notif-1',
          boardId: 'board-1',
          requesterUid: 'user-2',
          action: 'accept',
          requestType: 'edit',
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(boardService.respondCalls, 1);
      final inFlightState = bloc.state as NotificationsLoaded;
      expect(inFlightState.processingAccessRequestIds, contains('notif-1'));

      gate.complete();
      expect(await firstDone.future, isTrue);
      expect(boardService.respondCalls, 1);
      final doneState = bloc.state as NotificationsLoaded;
      expect(doneState.processingAccessRequestIds, isEmpty);
      expect(doneState.notifications.single['status'], 'accepted');
    },
  );
}
