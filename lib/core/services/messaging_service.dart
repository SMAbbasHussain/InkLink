import 'package:firebase_messaging/firebase_messaging.dart';

abstract class MessagingService {
  Future<NotificationSettings> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<RemoteMessage> get onMessage;
}

class MessagingServiceImpl implements MessagingService {
  final FirebaseMessaging _messaging;

  MessagingServiceImpl({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  @override
  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission();
  }

  @override
  Future<String?> getToken() {
    return _messaging.getToken();
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
}
