import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/services/cloud_functions_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../repositories/invitation/invitation_repository.dart';

abstract class InvitationService {
  Stream<List<Map<String, dynamic>>> watchPendingInvites();
  Future<bool> isOnline();
  Future<void> acceptInvite(String inviteId);
  Future<void> declineInvite(String inviteId);
}

class InvitationServiceImpl implements InvitationService {
  final InvitationRepository _invitationRepository;
  final CloudFunctionsService _cloudFunctionsService;
  final FirestoreService _firestoreService;

  InvitationServiceImpl({
    required InvitationRepository invitationRepository,
    required CloudFunctionsService cloudFunctionsService,
    required FirestoreService firestoreService,
  }) : _invitationRepository = invitationRepository,
       _cloudFunctionsService = cloudFunctionsService,
       _firestoreService = firestoreService;

  @override
  Stream<List<Map<String, dynamic>>> watchPendingInvites() {
    return _invitationRepository.watchPendingInvites();
  }

  @override
  Future<bool> isOnline() async {
    try {
      await _probeServerAvailability();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> acceptInvite(String inviteId) async {
    await _ensureOnlineForActions();
    await _callInviteFunction(
      functionName: 'acceptBoardInvite',
      inviteId: inviteId,
      failureMessage: 'Server failed to accept invite',
    );
    await _invitationRepository.removeHandledInvite(inviteId);
  }

  @override
  Future<void> declineInvite(String inviteId) async {
    await _ensureOnlineForActions();
    await _callInviteFunction(
      functionName: 'declineBoardInvite',
      inviteId: inviteId,
      failureMessage: 'Server failed to decline invite',
    );
    await _invitationRepository.removeHandledInvite(inviteId);
  }

  Future<void> _callInviteFunction({
    required String functionName,
    required String inviteId,
    required String failureMessage,
  }) async {
    try {
      final result = await _cloudFunctionsService
          .httpsCallable(functionName)
          .call({'inviteId': inviteId});

      if (result.data['success'] != true) {
        throw Exception(failureMessage);
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Cloud function call failed');
    } catch (_) {
      throw Exception('Connection error');
    }
  }

  Future<void> _ensureOnlineForActions() async {
    try {
      await _probeServerAvailability();
    } catch (_) {
      throw Exception('You are offline. Reconnect to manage board invites.');
    }
  }

  Future<void> _probeServerAvailability() {
    return _firestoreService
        .collection('users')
        .limit(1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 4));
  }
}
