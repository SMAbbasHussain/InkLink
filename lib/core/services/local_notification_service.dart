import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/invitation/invitation_service.dart';
import '../../domain/models/chat/chat_conversation_model.dart';
import '../../features/friends/view/friend_requests_screen.dart';
import '../../features/board_invitations/bloc/board_invitations_bloc.dart';
import '../../features/board_invitations/view/board_invites_screen.dart';
import '../../features/workspaces/view/workspace_invites_screen.dart';
import '../../features/chat/view/chat_thread_route.dart';

class LocalNotificationService {
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static int _uniqueIdCounter = 0;

  /// Unique-per-call id for one-shot notifications: mixes a millisecond
  /// timestamp with a process-local counter so rapid bursts never collide.
  /// The old `millisecondsSinceEpoch % 100000` made notifications that
  /// arrived close together silently replace each other.
  static int _nextUniqueNotificationId() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final counter = _uniqueIdCounter++ & 0xFFFF;
    return (millis ^ (counter << 12)) & 0x7FFFFFFF;
  }

  /// Deterministic id derived from a unique key (e.g. FCM messageId), so a
  /// re-delivered message replaces its own notification while different
  /// messages hash to different ids. Written out as FNV-1a because
  /// Dart's String.hashCode is randomized per app run.
  static int _stableNotificationId(String uniqueKey) {
    var hash = 0x811C9DC5;
    for (final code in uniqueKey.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

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
              invitationService: context.read<InvitationService>(),
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
      return;
    }

    if (type == 'workspace_invite') {
      navigator.push(
        MaterialPageRoute(builder: (_) => const WorkspaceInvitesScreen()),
      );
      return;
    }

    if (type == 'chat_message') {
      final conversationId = receivedAction.payload?['targetId'] ?? '';
      final senderName = receivedAction.payload?['senderName'] ?? 'Chat';
      final isGroup = receivedAction.payload?['isGroup'] == 'true';
      final conv = ChatConversationModel(
        id: conversationId,
        name: senderName,
        isGroup: isGroup,
      );
      navigator.push(
        buildChatThreadRoute(context, conversation: conv),
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

    final messageId = message.messageId;
    final notificationId = (messageId != null && messageId.isNotEmpty)
        ? _stableNotificationId('fcm:$messageId')
        : _nextUniqueNotificationId();

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId,
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

  static Future<void> showNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
    String? largeIcon,
  }) async {
    if (!_initialized || kIsWeb) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _nextUniqueNotificationId(),
        channelKey: 'inklink_notifications',
        title: title,
        body: body,
        largeIcon: largeIcon,
        notificationLayout: NotificationLayout.Messaging,
        payload: payload,
      ),
      actionButtons: [NotificationActionButton(key: 'OPEN', label: 'Open')],
    );
  }
}
