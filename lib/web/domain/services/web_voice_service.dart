import '../../../domain/models/canvas/voice_participant.dart';
import '../../../domain/services/voice/voice_service.dart';

/// Web platform capability adapter for [VoiceService].
///
/// Agora RTC voice calls are currently mobile-only, so web exposes an empty
/// participant stream and surfaces a clear message if a user tries to join.
class WebVoiceService implements VoiceService {
  static const String unavailableMessage =
      'Voice calls are available in the InkLink mobile app.';

  @override
  Stream<List<VoiceParticipant>> watchParticipants(String boardId) =>
      Stream.value(const <VoiceParticipant>[]);

  @override
  Stream<bool> watchIsInCall() => Stream.value(false);

  @override
  Stream<bool> watchIsMuted() => Stream.value(false);

  @override
  bool get isInCall => false;

  @override
  bool get isMuted => false;

  @override
  Stream<bool> watchIsSpeakerOn() => Stream.value(false);

  @override
  bool get isSpeakerOn => false;

  @override
  Future<void> toggleSpeaker() async {}

  @override
  List<VoiceParticipant> get currentParticipants => const [];

  @override
  String? get agoraAppId => null;

  @override
  Future<void> observeBoard(String boardId) async {}

  @override
  Future<void> unobserveBoard(String boardId) async {}

  @override
  Future<void> joinCall(String boardId) async =>
      throw UnsupportedError(unavailableMessage);

  @override
  Future<void> leaveCall(String boardId) async {}

  @override
  Future<void> toggleMute(String boardId) async {}

  @override
  Future<void> setSpeaking({
    required String boardId,
    required bool isSpeaking,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}
}
