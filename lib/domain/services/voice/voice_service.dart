import '../../../features/canvas/models/voice_participant.dart';

abstract class VoiceService {
  Stream<List<VoiceParticipant>> watchParticipants(String boardId);
  Stream<bool> watchIsInCall();
  Stream<bool> watchIsMuted();
  Stream<bool> watchIsSpeakerOn();

  bool get isInCall;
  bool get isMuted;
  bool get isSpeakerOn;
  List<VoiceParticipant> get currentParticipants;
  String? get agoraAppId;

  /// Watches call presence without joining the call, so everyone viewing the
  /// board can see that a call is in progress.
  Future<void> observeBoard(String boardId);
  Future<void> unobserveBoard(String boardId);

  Future<void> joinCall(String boardId);
  Future<void> leaveCall(String boardId);
  Future<void> toggleMute(String boardId);
  Future<void> toggleSpeaker();
  Future<void> setSpeaking({required String boardId, required bool isSpeaking});
  Future<void> disconnect();
  Future<void> dispose();
}
