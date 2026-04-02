import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../../core/services/firestore_service.dart';
import 'invitation_repository.dart';

class InvitationRepositoryImpl implements InvitationRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final CloudFunctionsService _functionsService;

  InvitationRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
    required CloudFunctionsService functionsService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _functionsService = functionsService;

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
        );
  }

  @override
  Future<void> acceptInvite(String inviteId) async {
    try {
      final result = await _functionsService
          .httpsCallable('acceptBoardInvite')
          .call({'inviteId': inviteId});

      if (result.data['success'] != true) {
        throw Exception('Server failed to accept invite');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to accept invite');
    }
  }

  @override
  Future<void> declineInvite(String inviteId) async {
    try {
      final result = await _functionsService
          .httpsCallable('declineBoardInvite')
          .call({'inviteId': inviteId});

      if (result.data['success'] != true) {
        throw Exception('Server failed to decline invite');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to decline invite');
    }
  }
}
