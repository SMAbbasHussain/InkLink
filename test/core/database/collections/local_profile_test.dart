import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/database/collections/local_profile.dart';

void main() {
  group('LocalProfile', () {
    test('constructor sets all fields', () {
      final now = DateTime.now();
      final profile = LocalProfile(
        uid: 'user-1',
        displayName: 'Alice',
        email: 'alice@example.com',
        bio: 'Hello!',
        photoURL: 'https://example.com/photo.jpg',
        friendCount: 10,
        boardCount: 5,
        lastSource: 'friends',
        friendshipStatus: FriendshipStatus.friend,
        cachedAtOverride: now,
      );

      expect(profile.uid, 'user-1');
      expect(profile.displayName, 'Alice');
      expect(profile.email, 'alice@example.com');
      expect(profile.bio, 'Hello!');
      expect(profile.photoURL, 'https://example.com/photo.jpg');
      expect(profile.friendCount, 10);
      expect(profile.boardCount, 5);
      expect(profile.lastSource, 'friends');
      expect(profile.friendshipStatus, FriendshipStatus.friend);
      expect(profile.cachedAt, now);
    });

    test('optional fields have sensible defaults', () {
      final profile = LocalProfile(
        uid: 'user-2',
        displayName: 'Bob',
        friendshipStatus: FriendshipStatus.nonFriend,
      );

      expect(profile.email, isNull);
      expect(profile.bio, isNull);
      expect(profile.photoURL, isNull);
      expect(profile.friendCount, 0);
      expect(profile.boardCount, 0);
      expect(profile.lastSource, isNull);
      expect(profile.cachedAt, isA<DateTime>());
    });

    test('all FriendshipStatus values are valid', () {
      expect(FriendshipStatus.values, hasLength(4));
      expect(FriendshipStatus.values, containsAll([
        FriendshipStatus.friend,
        FriendshipStatus.nonFriend,
        FriendshipStatus.self,
        FriendshipStatus.blocked,
      ]));
    });

    test('unique uid index', () {
      final a = LocalProfile(uid: 'same-id', displayName: 'A', friendshipStatus: FriendshipStatus.friend);
      final b = LocalProfile(uid: 'same-id', displayName: 'B', friendshipStatus: FriendshipStatus.nonFriend);

      expect(a.uid, b.uid);
      expect(a.displayName, isNot(b.displayName));
    });
  });
}
