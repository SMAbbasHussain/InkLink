import 'package:flutter/foundation.dart';

import '../../domain/repositories/board/board_repository.dart';
import '../../domain/repositories/friends/friends_repository.dart';
import '../../domain/repositories/invitation/invitation_repository.dart';

class DataPrefetchService {
  final BoardRepository boardRepository;
  final FriendsRepository friendsRepository;
  final InvitationRepository invitationRepository;

  DataPrefetchService({
    required this.boardRepository,
    required this.friendsRepository,
    required this.invitationRepository,
  });

  /// Phase 4E: Prefetch data on app launch to warm cache
  Future<void> prefetchInitialData(String uid) async {
    try {
      // Start syncing boards in background
      await boardRepository.startBoardsSync();

      // Prefetch friends list
      await _prefetchFriends();

      // Prefetch pending invitations
      await _prefetchInvitations();
    } catch (e) {
      // Silently fail - prefetching is a performance optimization, not critical
      debugPrint('Prefetch failed: $e');
    }
  }

  Future<void> _prefetchFriends() async {
    try {
      // Trigger friends sync - this will populate local cache via listener
      await friendsRepository.watchFriendsList().first;
    } catch (_) {
      // Prefetch is optional
    }
  }

  Future<void> _prefetchInvitations() async {
    try {
      // Trigger invitation sync
      await invitationRepository.watchPendingInvites().first;
    } catch (_) {
      // Prefetch is optional
    }
  }
}
