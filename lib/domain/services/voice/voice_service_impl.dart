import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/services/auth_service.dart';
import '../../../core/utils/network_config.dart';
import '../../../features/canvas/models/voice_participant.dart';
import 'rtc_media_client.dart';
import 'voice_service.dart';

class VoiceServiceImpl implements VoiceService {
  final AuthService _authService;
  final RtcMediaClient _rtcMediaClient;
  io.Socket? _socket;

  final StreamController<List<VoiceParticipant>> _participantsController =
      StreamController<List<VoiceParticipant>>.broadcast();
  final StreamController<bool> _isInCallController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _isMutedController =
      StreamController<bool>.broadcast();

  final List<VoiceParticipant> _participants = [];
  bool _isInCall = false;
  bool _isMuted = false;
  String? _activeBoardId;

  VoiceServiceImpl({
    required AuthService authService,
    RtcMediaClient? rtcMediaClient,
  })  : _authService = authService,
        _rtcMediaClient = rtcMediaClient ?? DefaultRtcMediaClient();

  @override
  bool get isInCall => _isInCall;

  @override
  bool get isMuted => _isMuted;

  @override
  List<VoiceParticipant> get currentParticipants => List.unmodifiable(_participants);

  @override
  String? get agoraAppId => dotenv.env['AGORA_APP_ID'];

  @override
  Stream<List<VoiceParticipant>> watchParticipants(String boardId) {
    return _participantsController.stream;
  }

  @override
  Stream<bool> watchIsInCall() => _isInCallController.stream;

  @override
  Stream<bool> watchIsMuted() => _isMutedController.stream;

  Future<bool> _ensureConnected() async {
    if (_socket != null && _socket!.connected) return true;

    final token = await _authService.getIdToken();
    if (token == null) return false;

    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      }
    } else {
      final serverUrl = resolveWebSocketUrl();
      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .disableAutoConnect()
            .build(),
      );

      _socket!.on('voice_participant_joined', (data) {
        try {
          if (data is Map) {
            final participant =
                VoiceParticipant.fromMap(Map<String, dynamic>.from(data));
            _participants.removeWhere((p) => p.uid == participant.uid);
            _participants.add(participant);
            _participantsController.add(List.from(_participants));
          }
        } catch (e) {
          developer.log('voice_participant_joined error: $e', name: 'VoiceService');
        }
      });

      _socket!.on('voice_participant_left', (data) {
        try {
          if (data is Map) {
            final uid = data['uid'] as String?;
            if (uid != null) {
              _participants.removeWhere((p) => p.uid == uid);
              _participantsController.add(List.from(_participants));
            }
          }
        } catch (e) {
          developer.log('voice_participant_left error: $e', name: 'VoiceService');
        }
      });

      _socket!.on('voice_speaking_changed', (data) {
        try {
          if (data is Map) {
            final uid = data['uid'] as String?;
            final isSpeaking = data['isSpeaking'] as bool? ?? false;
            final isMuted = data['isMuted'] as bool? ?? false;

            final idx = _participants.indexWhere((p) => p.uid == uid);
            if (idx != -1) {
              _participants[idx] = _participants[idx].copyWith(
                isSpeaking: isSpeaking,
                isMuted: isMuted,
              );
              _participantsController.add(List.from(_participants));
            }
          }
        } catch (e) {
          developer.log('voice_speaking_changed error: $e', name: 'VoiceService');
        }
      });

      _socket!.connect();
    }

    if (_socket!.connected) return true;

    final completer = Completer<void>();
    void onConnectHandler(_) {
      if (!completer.isCompleted) completer.complete();
    }

    _socket!.once('connect', onConnectHandler);

    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 5)),
    ]);

    return _socket != null && _socket!.connected;
  }

  @override
  Future<void> joinCall(String boardId) async {
    _activeBoardId = boardId;
    final connected = await _ensureConnected();
    if (!connected || _socket == null || !_socket!.connected) {
      _isInCall = false;
      _isInCallController.add(false);
      throw StateError(
        'Voice signaling server is unreachable. Please verify your connection.',
      );
    }

    final user = _authService.getCurrentUser();
    final displayName = user?.displayName ?? 'Anonymous';
    final photoUrl = user?.photoURL;

    final completer = Completer<void>();

    _socket?.emitWithAck(
      'join_voice_call',
      {
        'boardId': boardId,
        'displayName': displayName,
        'photoUrl': photoUrl,
      },
      ack: (dynamic res) async {
        try {
          if (res is Map && res['status'] == 'success') {
            final appId = res['appId']?.toString() ?? dotenv.env['AGORA_APP_ID'] ?? '';
            final channelName = res['channelName']?.toString() ?? 'board_$boardId';
            final token = res['token']?.toString() ?? '';
            final currentUid = _authService.getCurrentUserId() ?? '';

            // Consume server credentials to start RTC media session
            try {
              await _rtcMediaClient.joinSession(
                appId: appId,
                channelName: channelName,
                token: token,
                uid: currentUid,
              );
            } catch (mediaErr) {
              developer.log('RTC media session start error: $mediaErr', name: 'VoiceService');
            }

            _isInCall = true;
            _isMuted = false;
            _isInCallController.add(true);
            _isMutedController.add(false);

            final selfPart = res['participant'] as Map?;
            if (selfPart != null) {
              final p = VoiceParticipant.fromMap(
                Map<String, dynamic>.from(selfPart),
              );
              _participants.removeWhere((item) => item.uid == p.uid);
              _participants.add(p);
            }

            _refreshParticipants(boardId);
            completer.complete();
            return;
          }
          completer.completeError(
            Exception(res is Map ? res['message'] : 'Failed to join voice call'),
          );
        } catch (e) {
          completer.completeError(e);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _isInCall = false;
        _isInCallController.add(false);
        _activeBoardId = null;
        throw TimeoutException('Failed to join voice call. The server did not respond.');
      },
    );
  }

  void _refreshParticipants(String boardId) {
    _socket?.emitWithAck(
      'get_voice_participants',
      {'boardId': boardId},
      ack: (dynamic res) {
        try {
          if (res is Map && res['status'] == 'success') {
            final rawList = (res['participants'] as List?) ?? [];
            _participants.clear();
            for (final item in rawList) {
              if (item is Map) {
                _participants.add(
                  VoiceParticipant.fromMap(Map<String, dynamic>.from(item)),
                );
              }
            }
            _participantsController.add(List.from(_participants));
          }
        } catch (_) {}
      },
    );
  }

  @override
  Future<void> leaveCall(String boardId) async {
    _socket?.emit('leave_voice_call', {'boardId': boardId});
    try {
      await _rtcMediaClient.leaveSession();
    } catch (_) {}

    _isInCall = false;
    _isMuted = false;
    _activeBoardId = null;
    _participants.clear();

    _isInCallController.add(false);
    _isMutedController.add(false);
    _participantsController.add([]);
  }

  @override
  Future<void> toggleMute(String boardId) async {
    _isMuted = !_isMuted;
    _isMutedController.add(_isMuted);

    try {
      await _rtcMediaClient.setMicrophoneMuted(_isMuted);
    } catch (_) {}

    final currentUid = _authService.getCurrentUserId();
    final idx = _participants.indexWhere((p) => p.uid == currentUid);
    if (idx != -1) {
      _participants[idx] = _participants[idx].copyWith(
        isMuted: _isMuted,
        isSpeaking: _isMuted ? false : _participants[idx].isSpeaking,
      );
      _participantsController.add(List.from(_participants));
    }

    _socket?.emit('voice_speaking_state', {
      'boardId': boardId,
      'isMuted': _isMuted,
      'isSpeaking': false,
    });
  }

  @override
  Future<void> setSpeaking({
    required String boardId,
    required bool isSpeaking,
  }) async {
    if (_isMuted) return; // Muted user cannot be speaking

    final currentUid = _authService.getCurrentUserId();
    final idx = _participants.indexWhere((p) => p.uid == currentUid);
    if (idx != -1) {
      _participants[idx] = _participants[idx].copyWith(isSpeaking: isSpeaking);
      _participantsController.add(List.from(_participants));
    }

    _socket?.emit('voice_speaking_state', {
      'boardId': boardId,
      'isSpeaking': isSpeaking,
      'isMuted': _isMuted,
    });
  }

  @override
  Future<void> dispose() async {
    if (_isInCall && _activeBoardId != null) {
      await leaveCall(_activeBoardId!);
    }
    try {
      await _rtcMediaClient.dispose();
    } catch (_) {}
    _socket?.disconnect();
    _socket = null;
    await _participantsController.close();
    await _isInCallController.close();
    await _isMutedController.close();
  }
}

