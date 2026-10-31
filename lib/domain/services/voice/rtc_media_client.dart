import 'dart:async';
import 'dart:developer' as developer;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

abstract class RtcMediaClient {
  bool get isConnected;
  bool get isMicrophoneMuted;
  String? get currentChannel;
  String? get appId;

  /// Notified with the local user's speaking state, derived from the RTC
  /// engine's onAudioVolumeIndication (vad + volume). Fires while joined.
  void setLocalSpeakingListener(void Function(bool isSpeaking)? listener);

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

  RtcEngine? _engine;
  String? _engineAppId;
  final _speakingListeners = <void Function(bool)>[];
  bool _lastSpeaking = false;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isMicrophoneMuted => _isMicrophoneMuted;

  @override
  String? get currentChannel => _currentChannel;

  @override
  String? get appId => _appId;

  @override
  void setLocalSpeakingListener(void Function(bool isSpeaking)? listener) {
    _speakingListeners.clear();
    if (listener != null) {
      _speakingListeners.add(listener);
    }
  }

  void _notifySpeaking(bool speaking) {
    if (speaking == _lastSpeaking) return;
    _lastSpeaking = speaking;
    for (final listener in List.of(_speakingListeners)) {
      try {
        listener(speaking);
      } catch (e) {
        developer.log('Speaking listener error: $e', name: 'RtcMediaClient');
      }
    }
  }

  /// Maps a Firebase uid to a deterministic 32-bit RTC uid (Dart's own
  /// String.hashCode is not stable across sessions/platforms). The server
  /// mints wildcard (uid 0) tokens, so any numeric uid is admitted.
  int _rtcUidFor(String rawUid) {
    var hash = 0xcbf29ce4;
    for (final codeUnit in rawUid.codeUnits) {
      hash ^= codeUnit & 0xFF;
      hash = (hash & 0xFFFFFFFF) * 0x01000193 & 0xFFFFFFFF;
      hash ^= codeUnit >> 8;
    }
    return hash & 0x7FFFFFFF;
  }

  Future<RtcEngine?> _ensureEngine(String appId) async {
    if (_engine != null) {
      if (_engineAppId != appId) {
        // App IDs cannot be swapped on a live engine — recreate it.
        try {
          await _engine!.leaveChannel();
          await _engine!.release();
        } catch (_) {}
        _engine = null;
      } else {
        return _engine;
      }
    }
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      await engine.enableAudio();
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onAudioVolumeIndication:
              (RtcConnection connection, List<AudioVolumeInfo> speakers,
                  int speakerNumber, int totalVolume) {
            // The local user's record has uid == 0 and carries the vad flag.
            for (final speaker in speakers) {
              if (speaker.uid == 0) {
                final speaking =
                    (speaker.vad ?? 1) == 1 && (speaker.volume ?? 0) > 10;
                _notifySpeaking(speaking);
              }
            }
          },
        ),
      );
      _engine = engine;
      _engineAppId = appId;
      developer.log('RTC engine initialized', name: 'RtcMediaClient');
      return engine;
    } catch (e, st) {
      developer.log('RTC engine initialize failed: $e',
          name: 'RtcMediaClient', stackTrace: st);
      return null;
    }
  }

  @override
  Future<void> initialize({required String appId}) async {
    _appId = appId;
    await _ensureEngine(appId);
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
      developer.log('Microphone permission check/request failed: $e',
          name: 'RtcMediaClient');
    }

    final engine = await _ensureEngine(appId);
    if (engine == null) {
      throw StateError('RTC engine could not be initialized (appId: $appId)');
    }

    try {
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );
      await engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: _rtcUidFor(uid),
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
        ),
      );
      _isConnected = true;
      _isMicrophoneMuted = false;
      developer.log(
        'Joined RTC media session for channel: $channelName (appId: $appId, uid: $uid, tokenLength: ${token.length})',
        name: 'RtcMediaClient',
      );
    } catch (e, st) {
      _isConnected = false;
      developer.log('RTC joinChannel failed: $e',
          name: 'RtcMediaClient', stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> setMicrophoneMuted(bool muted) async {
    _isMicrophoneMuted = muted;
    if (_isConnected) {
      try {
        await _engine?.muteLocalAudioStream(muted);
      } catch (e) {
        developer.log('muteLocalAudioStream failed: $e', name: 'RtcMediaClient');
      }
    }
    developer.log('RTC microphone capture set to muted: $muted',
        name: 'RtcMediaClient');
  }

  @override
  Future<void> leaveSession() async {
    try {
      await _engine?.leaveChannel();
    } catch (e) {
      developer.log('leaveChannel failed: $e', name: 'RtcMediaClient');
    }
    _isConnected = false;
    _isMicrophoneMuted = false;
    _currentChannel = null;
    _notifySpeaking(false);
    developer.log('Left RTC media session and stopped audio capture',
        name: 'RtcMediaClient');
  }

  @override
  Future<void> dispose() async {
    await leaveSession();
    try {
      await _engine?.release();
    } catch (e) {
      developer.log('RTC engine release failed: $e', name: 'RtcMediaClient');
    }
    _engine = null;
    _engineAppId = null;
  }
}
