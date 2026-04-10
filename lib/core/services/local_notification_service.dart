import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/invitation/invitation_repository.dart';
import '../../features/friends/view/friend_requests_screen.dart';
import '../../features/board_invitations/bloc/board_invitations_bloc.dart';
import '../../features/board_invitations/view/board_invites_screen.dart';

class LocalNotificationService {
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (_initialized || kIsWeb) return;
    _navigatorKey = navigatorKey;

    await AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: 'inklink_notifications',
        channelName: 'InkLink Notifications',
        channelDescription: 'Friend requests and board invites',
        importance: NotificationImportance.High,
      ),
    ], debug: false);

    await AwesomeNotifications().requestPermissionToSendNotifications();
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
    );
    _initialized = true;
  }

  static Future<void> _onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    final navigator = _navigatorKey?.currentState;
    final context = _navigatorKey?.currentContext;
    if (navigator == null || context == null) return;

    final type = receivedAction.payload?['type'];
    if (type == 'board_invite') {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => BoardInvitationsBloc(
              invitationRepository: context.read<InvitationRepository>(),
            )..add(const BoardInvitationsLoadRequested()),
            child: const BoardInvitesScreen(),
          ),
        ),
      );
      return;
    }

    if (type == 'friend_request' || type == 'friend_request_accepted') {
      navigator.push(
        MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
      );
    }
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    if (!_initialized || kIsWeb) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final payloadRecipientUid = message.data['recipientUid']?.toString();
    if (currentUid == null) return;
    if (payloadRecipientUid != null && payloadRecipientUid != currentUid) {
      return;
    }

    final senderName =
        message.data['senderName']?.toString() ??
        message.notification?.title ??
        'InkLink';
    final senderPhotoUrl = message.data['senderPhotoUrl']?.toString();
    final body =
        (message.data['body']?.toString() ??
                message.notification?.body ??
                'sent you a notification')
            .trim();

    final title = senderName;
    final content = body;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        channelKey: 'inklink_notifications',
        title: title,
        body: content,
        largeIcon: senderPhotoUrl,
        notificationLayout: NotificationLayout.Messaging,
        payload: message.data.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      ),
      actionButtons: [NotificationActionButton(key: 'OPEN', label: 'Open')],
    );
  }
}
