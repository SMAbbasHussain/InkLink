import '../../../features/canvas/models/voice_participant.dart';

abstract class VoiceService {
  Stream<List<VoiceParticipant>> watchParticipants(String boardId);
  Stream<bool> watchIsInCall();
  Stream<bool> watchIsMuted();

  bool get isInCall;
  bool get isMuted;
  List<VoiceParticipant> get currentParticipants;
  String? get agoraAppId;

  Future<void> joinCall(String boardId);
  Future<void> leaveCall(String boardId);
  Future<void> toggleMute(String boardId);
  Future<void> setSpeaking({required String boardId, required bool isSpeaking});
  Future<void> dispose();
}
