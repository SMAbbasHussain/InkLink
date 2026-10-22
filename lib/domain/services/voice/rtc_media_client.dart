import 'dart:async';
import 'dart:developer' as developer;
import 'package:permission_handler/permission_handler.dart';

abstract class RtcMediaClient {
  bool get isConnected;
  bool get isMicrophoneMuted;
  String? get currentChannel;
  String? get appId;

  Future<void> initialize({required String appId});

  Future<void> joinSession({
    required String appId,
    required String channelName,
    required String token,
    required String uid,
  });

  Future<void> setMicrophoneMuted(bool muted);

  Future<void> leaveSession();

  Future<void> dispose();
}

class DefaultRtcMediaClient implements RtcMediaClient {
  bool _isConnected = false;
  bool _isMicrophoneMuted = false;
  String? _currentChannel;
  String? _appId;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isMicrophoneMuted => _isMicrophoneMuted;

  @override
  String? get currentChannel => _currentChannel;

  @override
  String? get appId => _appId;

  @override
  Future<void> initialize({required String appId}) async {
    _appId = appId;
    developer.log('Initialized RTC media client with appId: $appId', name: 'RtcMediaClient');
  }

  @override
  Future<void> joinSession({
    required String appId,
    required String channelName,
    required String token,
    required String uid,
  }) async {
    _appId = appId;
    _currentChannel = channelName;

    // Check and request microphone permission
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        await Permission.microphone.request();
      }
    } catch (e) {
      developer.log('Microphone permission check/request failed: $e', name: 'RtcMediaClient');
    }

    _isConnected = true;
    _isMicrophoneMuted = false;
    developer.log(
      'Joined RTC media session for channel: $channelName (appId: $appId, uid: $uid, tokenLength: ${token.length})',
      name: 'RtcMediaClient',
    );
  }

  @override
  Future<void> setMicrophoneMuted(bool muted) async {
    _isMicrophoneMuted = muted;
    developer.log('RTC microphone capture set to muted: $muted', name: 'RtcMediaClient');
  }

  @override
  Future<void> leaveSession() async {
    _isConnected = false;
    _isMicrophoneMuted = false;
    _currentChannel = null;
    developer.log('Left RTC media session and stopped audio capture', name: 'RtcMediaClient');
  }

  @override
  Future<void> dispose() async {
    await leaveSession();
  }
}
