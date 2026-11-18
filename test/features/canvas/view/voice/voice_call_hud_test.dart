import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/domain/services/voice/rtc_media_client.dart';
import 'package:inklink/domain/services/voice/voice_service.dart';
import 'package:inklink/domain/services/voice/voice_service_impl.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/voice/voice_call_hud.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<void> deleteAccount() async {}

  @override
  User? getCurrentUser() => null;

  @override
  String? getCurrentUserId() => 'user-1';

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;

  @override
  FirebaseAuth getInstance() => throw UnimplementedError();

  @override
  Future<EmailVerificationStatus> reloadAndCheckEmailVerified() async =>
      EmailVerificationStatus.verified;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class _FakeRtcMediaClient implements RtcMediaClient {
  bool _isConnected = false;
  bool _isMicrophoneMuted = false;
  bool _isSpeakerphoneEnabled = false;
  final List<bool> speakerCalls = [];

  @override
  String? get appId => null;

  @override
  String? get currentChannel => null;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isMicrophoneMuted => _isMicrophoneMuted;

  @override
  bool get isSpeakerphoneEnabled => _isSpeakerphoneEnabled;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize({required String appId}) async {}

  @override
  Future<void> joinSession({
    required String appId,
    required String channelName,
    required String token,
    required String uid,
  }) async {
    _isConnected = true;
  }

  @override
  Future<void> leaveSession() async {
    _isConnected = false;
    _isMicrophoneMuted = false;
    _isSpeakerphoneEnabled = false;
  }

  @override
  void setLocalSpeakingListener(void Function(bool isSpeaking)? listener) {}

  @override
  Future<void> setMicrophoneMuted(bool muted) async {
    _isMicrophoneMuted = muted;
  }

  @override
  Future<void> setSpeakerphoneEnabled(bool enabled) async {
    _isSpeakerphoneEnabled = enabled;
    speakerCalls.add(enabled);
  }
}

class _FakeVoiceService implements VoiceService {
  final _participantsController =
      StreamController<List<VoiceParticipant>>.broadcast();
  final _isInCallController = StreamController<bool>.broadcast();
  final _isMutedController = StreamController<bool>.broadcast();
  final _isSpeakerOnController = StreamController<bool>.broadcast();

  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  int toggleSpeakerCalls = 0;

  @override
  String? get agoraAppId => null;

  @override
  List<VoiceParticipant> get currentParticipants => const [];

  @override
  bool get isInCall => _isInCall;

  @override
  bool get isMuted => _isMuted;

  @override
  bool get isSpeakerOn => _isSpeakerOn;

  @override
  Future<void> disconnect() async {
    _isInCall = false;
    _isMuted = false;
    _isSpeakerOn = false;
  }

  @override
  Future<void> dispose() async {
    await _participantsController.close();
    await _isInCallController.close();
    await _isMutedController.close();
    await _isSpeakerOnController.close();
  }

  @override
  Future<void> joinCall(String boardId) async {
    _isInCall = true;
    _isInCallController.add(true);
    _isMutedController.add(_isMuted);
    _isSpeakerOnController.add(_isSpeakerOn);
  }

  @override
  Future<void> leaveCall(String boardId) async {
    _isInCall = false;
    _isMuted = false;
    _isSpeakerOn = false;
    _isInCallController.add(false);
    _isMutedController.add(false);
    _isSpeakerOnController.add(false);
  }

  @override
  Future<void> observeBoard(String boardId) async {}

  @override
  Future<void> setSpeaking({
    required String boardId,
    required bool isSpeaking,
  }) async {}

  @override
  Future<void> toggleMute(String boardId) async {
    _isMuted = !_isMuted;
    _isMutedController.add(_isMuted);
  }

  @override
  Future<void> toggleSpeaker() async {
    toggleSpeakerCalls++;
    _isSpeakerOn = !_isSpeakerOn;
    _isSpeakerOnController.add(_isSpeakerOn);
  }

  @override
  Future<void> unobserveBoard(String boardId) async {}

  @override
  Stream<bool> watchIsInCall() => _isInCallController.stream;

  @override
  Stream<bool> watchIsMuted() => _isMutedController.stream;

  @override
  Stream<bool> watchIsSpeakerOn() => _isSpeakerOnController.stream;

  @override
  Stream<List<VoiceParticipant>> watchParticipants(String boardId) =>
      _participantsController.stream;
}

Widget _host(CanvasBloc bloc) {
  return MaterialApp(
    theme: InkTheme.light(),
    home: Scaffold(
      body: BlocProvider<CanvasBloc>.value(
        value: bloc,
        child: const Stack(children: [VoiceCallHud()]),
      ),
    ),
  );
}

void main() {
  group('VoiceCallHud speaker option', () {
    Future<({CanvasBloc bloc, _FakeVoiceService voiceService})> createTestBloc(
      WidgetTester tester,
    ) async {
      final voiceService = _FakeVoiceService();
      final crdtAdapter = await CanvasDocAdapterFactory.create();
      final bloc = CanvasBloc(
        boardId: 'board-voice-test',
        voiceService: voiceService,
        crdtAdapter: crdtAdapter,
      );
      addTearDown(() async {
        await bloc.close();
        await voiceService.dispose();
      });
      bloc.add(const CanvasInitializeCrdt('board-voice-test'));
      await tester.pump();
      await tester.pump();
      return (bloc: bloc, voiceService: voiceService);
    }

    testWidgets('hides speaker button when observing a call but not joined', (
      tester,
    ) async {
      final (:bloc, :voiceService) = await createTestBloc(tester);
      bloc.add(
        const CanvasVoiceParticipantsUpdated([
          VoiceParticipant(uid: 'u1', displayName: 'Alice', joinedAt: 1),
        ]),
      );
      await tester.pumpWidget(_host(bloc));
      await tester.pump();

      expect(find.byTooltip('Join Call'), findsOneWidget);
      expect(find.byTooltip('Speaker On'), findsNothing);
      expect(find.byTooltip('Speaker Off'), findsNothing);
      expect(find.byTooltip('Mute Mic'), findsNothing);
    });

    testWidgets('shows and toggles speaker button during an active call', (
      tester,
    ) async {
      final (:bloc, :voiceService) = await createTestBloc(tester);
      bloc.add(const CanvasVoiceCallStatusChanged(true));
      await tester.pumpWidget(_host(bloc));
      await tester.pump();

      expect(find.byTooltip('Mute Mic'), findsOneWidget);
      expect(find.byTooltip('Speaker On'), findsOneWidget);
      expect(find.byIcon(LucideIcons.volume1), findsOneWidget);
      expect(find.byTooltip('Leave Call'), findsOneWidget);

      await tester.tap(find.byTooltip('Speaker On'));
      await tester.pumpAndSettle();

      expect(voiceService.toggleSpeakerCalls, 1);
      expect(bloc.state.isSpeakerOn, isTrue);
      expect(find.byTooltip('Speaker Off'), findsOneWidget);
      expect(find.byIcon(LucideIcons.volume2), findsOneWidget);

      await tester.tap(find.byTooltip('Speaker Off'));
      await tester.pumpAndSettle();

      expect(voiceService.toggleSpeakerCalls, 2);
      expect(bloc.state.isSpeakerOn, isFalse);
      expect(find.byTooltip('Speaker On'), findsOneWidget);
      expect(find.byIcon(LucideIcons.volume1), findsOneWidget);
    });
  });

  group('VoiceServiceImpl speaker toggle', () {
    test('toggles speakerphone on RtcMediaClient and resets on disconnect', () async {
      final rtcClient = _FakeRtcMediaClient();
      final service = VoiceServiceImpl(
        authService: _FakeAuthService(),
        rtcMediaClient: rtcClient,
      );

      final emitted = <bool>[];
      final sub = service.watchIsSpeakerOn().listen(emitted.add);

      expect(service.isSpeakerOn, isFalse);
      expect(rtcClient.isSpeakerphoneEnabled, isFalse);

      await service.toggleSpeaker();
      await Future<void>.delayed(Duration.zero);
      expect(service.isSpeakerOn, isTrue);
      expect(rtcClient.isSpeakerphoneEnabled, isTrue);
      expect(rtcClient.speakerCalls, [true]);

      await service.toggleSpeaker();
      await Future<void>.delayed(Duration.zero);
      expect(service.isSpeakerOn, isFalse);
      expect(rtcClient.isSpeakerphoneEnabled, isFalse);
      expect(rtcClient.speakerCalls, [true, false]);

      await service.toggleSpeaker();
      await service.disconnect();
      await Future<void>.delayed(Duration.zero);
      expect(service.isSpeakerOn, isFalse);
      expect(emitted, [true, false, true, false]);

      await sub.cancel();
      await service.dispose();
    });
  });
}
