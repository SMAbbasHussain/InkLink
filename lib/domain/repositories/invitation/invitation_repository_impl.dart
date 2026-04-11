import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import 'invitation_repository.dart';

class InvitationRepositoryImpl implements InvitationRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  InvitationRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
  }) : _firestoreService = firestoreService,
       _authService = authService;

  @override
  Stream<List<Map<String, dynamic>>> watchPendingInvites() {
    final uid = _authService.getCurrentUserId();
    if (uid == null) {
      return Stream.value([]);
    }

    return _firestoreService
        .collection('board_invites')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        )
        .handleError((error, stackTrace) {
          // Log the error - stream will emit the error event
          print('Error watching pending invites: $error');
        });
  }
}
