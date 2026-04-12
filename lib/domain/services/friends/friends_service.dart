import 'package:rxdart/rxdart.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:developer' as developer;

import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../repositories/friends/friends_repository.dart';

class FriendsInfoSnapshot {
  final List<Map<String, dynamic>> friends;
  final List<Map<String, dynamic>> incomingRequests;
  final List<Map<String, dynamic>> outgoingRequests;

  const FriendsInfoSnapshot({
    required this.friends,
    required this.incomingRequests,
    required this.outgoingRequests,
  });
}

abstract class FriendsService {
  Stream<FriendsInfoSnapshot> watchFriendsInfo();
  Stream<List<Map<String, dynamic>>> watchBlockedUsers();
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email);
  Future<bool> isOnline();
  Future<void> sendFriendRequest(String targetUid);
  Future<void> acceptFriendRequest(String requestId, String senderUid);
  Future<void> declineFriendRequest(String requestId);
  Future<void> unfriendUser(String targetUid);
  Future<void> blockUser(String targetUid, {String? reason});
  Future<void> reportUser(String targetUid, {String? reason});
  Future<void> unblockUser(String targetUid);
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
    return Rx.combineLatest3(
      _friendsRepository.watchFriendsList(),
      _friendsRepository.watchIncomingRequests(),
      _friendsRepository.watchOutgoingRequests(),
      (
        List<Map<String, dynamic>> friends,
        List<Map<String, dynamic>> incomingRequests,
        List<Map<String, dynamic>> outgoingRequests,
      ) {
        return FriendsInfoSnapshot(
          friends: friends,
          incomingRequests: incomingRequests,
          outgoingRequests: outgoingRequests,
        );
      },
    );
  }

  @override
  Stream<List<Map<String, dynamic>>> watchBlockedUsers() {
    return _friendsRepository.watchBlockedUsers();
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
  Future<bool> isOnline() async {
    try {
      await _friendsRepository.probeServerAvailability();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> sendFriendRequest(String targetUid) async {
    final normalizedTargetUid = targetUid.trim();
    if (normalizedTargetUid.isEmpty) return;

    final currentUid = _authService.getCurrentUserId();
    if (currentUid != null && currentUid == normalizedTargetUid) {
      return;
    }

    await _ensureOnlineForActions();

    await _callFriendFunction(
      functionName: 'sendFriendRequest',
      payload: {'targetUid': normalizedTargetUid},
      failureMessage: 'Server failed to send request',
    );
  }

  @override
  Future<void> acceptFriendRequest(String requestId, String senderUid) async {
    await _ensureOnlineForActions();
    await _callFriendFunction(
      functionName: 'acceptFriendRequest',
      payload: {'requestId': requestId},
      failureMessage: 'Server failed to establish friendship',
    );
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    await _ensureOnlineForActions();
    await _callFriendFunction(
      functionName: 'declineFriendRequest',
      payload: {'requestId': requestId},
      failureMessage: 'Server failed to decline request',
    );
  }

  @override
  Future<void> unfriendUser(String targetUid) async {
    final normalizedTargetUid = targetUid.trim();
    if (normalizedTargetUid.isEmpty) return;

    await _ensureOnlineForActions();
    await _callFriendFunction(
      functionName: 'unfriendUser',
      payload: {'targetUid': normalizedTargetUid},
      failureMessage: 'Server failed to remove friendship',
    );
  }

  @override
  Future<void> blockUser(String targetUid, {String? reason}) async {
    final normalizedTargetUid = targetUid.trim();
    if (normalizedTargetUid.isEmpty) return;

    await _ensureOnlineForActions();
    await _callFriendFunction(
      functionName: 'blockUser',
      payload: {
        'targetUid': normalizedTargetUid,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      failureMessage: 'Server failed to block user',
    );

    await _friendsRepository.cacheBlockedUser(normalizedTargetUid);
  }

  @override
  Future<void> reportUser(String targetUid, {String? reason}) async {
    final normalizedTargetUid = targetUid.trim();
    if (normalizedTargetUid.isEmpty) return;

    await _ensureOnlineForActions();
    await _callFriendFunction(
      functionName: 'reportUser',
      payload: {
        'targetUid': normalizedTargetUid,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      failureMessage: 'Server failed to submit report',
    );
  }

  @override
  Future<void> unblockUser(String targetUid) async {
    final normalizedTargetUid = targetUid.trim();
    if (normalizedTargetUid.isEmpty) return;

    await _ensureOnlineForActions();
    await _callFriendFunction(
      functionName: 'unblockUser',
      payload: {'targetUid': normalizedTargetUid},
      failureMessage: 'Server failed to unblock user',
    );

    await _friendsRepository.removeBlockedUser(normalizedTargetUid);
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

  Future<void> _ensureOnlineForActions() async {
    try {
      await _friendsRepository.probeServerAvailability();
    } catch (_) {
      throw Exception('You are offline. Reconnect to manage friend requests.');
    }
  }
}
