import 'package:rxdart/rxdart.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:developer' as developer;

import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../repositories/friends/friends_repository.dart';

class FriendsInfoSnapshot {
  final List<Map<String, dynamic>> friends;
  final List<Map<String, dynamic>> incomingRequests;

  const FriendsInfoSnapshot({
    required this.friends,
    required this.incomingRequests,
  });
}

abstract class FriendsService {
  Stream<FriendsInfoSnapshot> watchFriendsInfo();
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email);
  Future<void> sendFriendRequest(String targetUid);
  Future<void> acceptFriendRequest(String requestId, String senderUid);
  Future<void> declineFriendRequest(String requestId);
}

class FriendsServiceImpl implements FriendsService {
  final FriendsRepository _friendsRepository;
  final AuthService _authService;
  final CloudFunctionsService _cloudFunctionsService;

  FriendsServiceImpl({
    required FriendsRepository friendsRepository,
    required AuthService authService,
    required CloudFunctionsService cloudFunctionsService,
  }) : _friendsRepository = friendsRepository,
       _authService = authService,
       _cloudFunctionsService = cloudFunctionsService;

  @override
  Stream<FriendsInfoSnapshot> watchFriendsInfo() {
    return Rx.combineLatest2(
      _friendsRepository.watchFriendsList(),
      _friendsRepository.watchIncomingRequests(),
      (
        List<Map<String, dynamic>> friends,
        List<Map<String, dynamic>> requests,
      ) {
        return FriendsInfoSnapshot(
          friends: friends,
          incomingRequests: requests,
        );
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return Future.value(<Map<String, dynamic>>[]);
    }
    return _friendsRepository.searchUsersByEmail(normalizedEmail);
  }

  @override
  Future<void> sendFriendRequest(String targetUid) async {
    final normalizedTargetUid = targetUid.trim();
    if (normalizedTargetUid.isEmpty) return;

    final currentUid = _authService.getCurrentUserId();
    if (currentUid != null && currentUid == normalizedTargetUid) {
      return;
    }

    await _callFriendFunction(
      functionName: 'sendFriendRequest',
      payload: {'targetUid': normalizedTargetUid},
      failureMessage: 'Server failed to send request',
    );
  }

  @override
  Future<void> acceptFriendRequest(String requestId, String senderUid) async {
    await _callFriendFunction(
      functionName: 'acceptFriendRequest',
      payload: {'requestId': requestId},
      failureMessage: 'Server failed to establish friendship',
    );
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    await _callFriendFunction(
      functionName: 'declineFriendRequest',
      payload: {'requestId': requestId},
      failureMessage: 'Server failed to decline request',
    );
  }

  Future<void> _callFriendFunction({
    required String functionName,
    required Map<String, dynamic> payload,
    required String failureMessage,
  }) async {
    try {
      final result = await _cloudFunctionsService
          .httpsCallable(functionName)
          .call(payload);

      if (result.data['success'] != true) {
        throw Exception(failureMessage);
      }
    } on FirebaseFunctionsException catch (e) {
      developer.log(
        'Cloud Function Error: ${e.code} - ${e.message}',
        name: 'FriendsServiceImpl',
      );
      throw Exception(e.message ?? 'Cloud function call failed');
    } catch (e) {
      throw Exception('Connection error');
    }
  }
}
