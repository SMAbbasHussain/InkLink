import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

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
  int _reconnectAttempts = 0;
  bool _reconnectScheduled = false;
  bool _disposed = false;

  VoiceServiceImpl({
    required AuthService authService,
    RtcMediaClient? rtcMediaClient,
  })  : _authService = authService,
        _rtcMediaClient = rtcMediaClient ?? DefaultRtcMediaClient() {
    // Drive local speaking state from the RTC engine's volume indication.
    // The server broadcasts `voice_speaking_changed` to the whole voice room
    // (including the sender), but the socket handler below only refreshes the
    // participants list — it never re-invokes setSpeaking, so no loop forms.
    _rtcMediaClient.setLocalSpeakingListener((speaking) {
      if (_disposed || !_isInCall || _isMuted) return;
      final boardId = _activeBoardId;
      if (boardId == null) return;
      unawaited(setSpeaking(boardId: boardId, isSpeaking: speaking));
    });
  }

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

  io.Socket _buildSocket(String token) {
    final socket = io.io(
      resolveWebSocketUrl(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          // Reconnection is owned by this service: the built-in
          // auto-reconnect would reuse the token frozen at creation time and
          // fail forever once that token expires.
          .disableAutoConnect()
          .disableReconnection()
          .build(),
    );

    socket.on('voice_participant_joined', (data) {
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

    socket.on('voice_participant_left', (data) {
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

    socket.on('voice_speaking_changed', (data) {
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

    socket.on('disconnect', (data) {
      developer.log('Voice socket disconnected; scheduling reconnect with fresh token',
          name: 'VoiceService');
      _scheduleReconnect();
    });

    socket.on('connect_error', (data) {
      developer.log('Voice socket connect_error: $data; scheduling reconnect with fresh token',
          name: 'VoiceService');
      _scheduleReconnect();
    });

    return socket;
  }

  /// Capped exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s, 30s, ...
  Duration get _reconnectDelay =>
      Duration(seconds: math.min(30, 1 << _reconnectAttempts.clamp(0, 5)));

  void _scheduleReconnect() {
    if (_disposed || _reconnectScheduled) return;
    _reconnectScheduled = true;
    final delay = _reconnectDelay;
    _reconnectAttempts++;
    Future.delayed(delay, () {
      _reconnectScheduled = false;
      if (_disposed) return;
      if (_socket != null && _socket!.connected) return;
      unawaited(_ensureConnected());
    });
  }

  void _teardownSocket() {
    final stale = _socket;
    _socket = null;
    if (stale == null) return;
    try {
      stale.dispose();
    } catch (e) {
      developer.log('Stale voice socket dispose failed: $e', name: 'VoiceService');
      try {
        stale.disconnect();
      } catch (_) {}
    }
  }

  Future<bool> _ensureConnected() async {
    if (_socket != null && _socket!.connected) return true;

    // Tear down any stale socket — its auth token is frozen at creation, so
    // reconnecting it would fail forever after the token expires.
    _teardownSocket();

    final token = await _authService.getIdToken();
    if (token == null) return false;

    final socket = _buildSocket(token);
    _socket = socket;
    socket.connect();

    final completer = Completer<void>();
    socket.once('connect', (_) {
      if (!completer.isCompleted) completer.complete();
    });

    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 5)),
    ]);

    if (socket.connected) {
      _reconnectAttempts = 0;
      // If a call was active while the socket dropped, re-register with the
      // signaling room so participant/speaking events resume.
      final boardId = _activeBoardId;
      if (_isInCall && boardId != null) {
        unawaited(
          joinCall(boardId).catchError((e) {
            developer.log('Voice rejoin after reconnect failed: $e', name: 'VoiceService');
          }),
        );
      }
      return true;
    }

    _scheduleReconnect();
    return false;
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
              // Preserve local mute state across (re)joins.
              try {
                await _rtcMediaClient.setMicrophoneMuted(_isMuted);
              } catch (_) {}
            } catch (mediaErr) {
              developer.log('RTC media session start error: $mediaErr', name: 'VoiceService');
            }

            _isInCall = true;
            _isInCallController.add(true);
            // Only force-unmute on a fresh call — rejoining after a socket
            // reconnect must not silently unmute a muted user.
            _isMutedController.add(_isMuted);

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
    // Flip local state before tearing down media: the RTC engine reports a
    // final not-speaking event on leave, which the speaking listener must not
    // forward (the participant is already leaving the voice room).
    _isInCall = false;
    _activeBoardId = null;

    _socket?.emit('leave_voice_call', {'boardId': boardId});
    try {
      await _rtcMediaClient.leaveSession();
    } catch (_) {}

    _isMuted = false;
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
    _disposed = true;
    if (_isInCall && _activeBoardId != null) {
      try {
        await leaveCall(_activeBoardId!);
      } catch (_) {}
    }
    try {
      await _rtcMediaClient.dispose();
    } catch (_) {}
    _teardownSocket();
    await _participantsController.close();
    await _isInCallController.close();
    await _isMutedController.close();
  }
}

