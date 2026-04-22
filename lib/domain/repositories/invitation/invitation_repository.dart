abstract class InvitationRepository {
  Stream<List<Map<String, dynamic>>> watchPendingInvites();
  Future<void> removeHandledInvite(String inviteId);
  Future<void> probeServerAvailability();
}
