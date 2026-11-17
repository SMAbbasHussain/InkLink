import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/web/data/web_mappers.dart';

void main() {
  group('UserBoardIndex', () {
    test('splits owned and joined, using boardId or the doc id', () {
      final index = UserBoardIndex.fromDocs([
        const MapEntry('a', {'relation': 'owned'}),
        const MapEntry('doc-b', {'boardId': 'b', 'relation': 'joined'}),
        const MapEntry('c', <String, dynamic>{}),
      ]);
      expect(index.owned, {'a'});
      expect(index.joined, {'b', 'c'});
      expect(index.all, {'a', 'b', 'c'});
    });

    test('a board listed as both owned and joined counts as owned', () {
      final index = UserBoardIndex.fromDocs([
        const MapEntry('x', {'relation': 'joined'}),
        const MapEntry('x2', {'boardId': 'x', 'relation': 'owned'}),
      ]);
      expect(index.owned, {'x'});
      expect(index.joined, isEmpty);
    });

    test('ignores empty ids', () {
      final index = UserBoardIndex.fromDocs([
        const MapEntry('', {'boardId': '  '}),
      ]);
      expect(index.all, isEmpty);
    });
  });

  test('chunked splits into whereIn-sized batches', () {
    expect(chunked(List.generate(23, (i) => i)).map((c) => c.length), [10, 10, 3]);
    expect(chunked(<int>[]), isEmpty);
    expect(() => chunked([1], 0), throwsArgumentError);
  });

  test('board links use the deep-link host the app accepts', () {
    expect(boardAppLink('abc'), 'https://inklink.app/board/abc');
    expect(boardSchemeLink('abc'), 'inklink://board/abc');
  });

  test('chat messages are hidden from the notification feed', () {
    expect(isFeedNotification({'type': 'chat_message'}), isFalse);
    expect(isFeedNotification({'type': 'board_invite'}), isTrue);
    expect(isFeedNotification({}), isTrue);
  });

  test('initialsOf', () {
    expect(initialsOf('Fahad Basraa'), 'FB');
    expect(initialsOf('  ink  '), 'I');
    expect(initialsOf('a b c'), 'AC');
    expect(initialsOf(null), '?');
    expect(initialsOf('   '), '?');
  });

  test('profile validation', () {
    expect(validateDisplayName(''), isNotNull);
    expect(validateDisplayName('  '), isNotNull);
    expect(validateDisplayName('Fahad'), isNull);
    expect(validateDisplayName('x' * 51), isNotNull);
    expect(validateBio('x' * 160), isNull);
    expect(validateBio('x' * 161), isNotNull);
  });

  test('timeAgo', () {
    final now = DateTime(2026, 11, 17, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 10)), now: now), 'just now');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
    expect(timeAgo(now.subtract(const Duration(days: 2)), now: now), '2d ago');
    expect(timeAgo(DateTime(2026, 1, 5), now: now), '2026-01-05');
    expect(timeAgo(now.add(const Duration(minutes: 1)), now: now), 'just now');
  });
}
