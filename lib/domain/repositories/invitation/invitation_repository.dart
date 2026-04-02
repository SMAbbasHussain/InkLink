abstract class InvitationRepository {
  Stream<List<Map<String, dynamic>>> watchPendingInvites();
  Future<void> acceptInvite(String inviteId);
  Future<void> declineInvite(String inviteId);
}
