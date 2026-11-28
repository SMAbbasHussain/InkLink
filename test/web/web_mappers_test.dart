import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/web/core/web_formatters.dart';
import 'package:inklink/web/core/web_stream_utils.dart';
import 'package:inklink/web/domain/models/user_board_index.dart';
import 'package:inklink/web/domain/models/web_notification_rules.dart';

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

  test(
    'workspace boards: hidden links and boards the user lacks are left out',
    () {
      final ids = visibleWorkspaceBoardIds(
        [
          const MapEntry('a', {'boardId': 'a'}),
          const MapEntry('b', {'boardId': 'b', 'visible': false}),
          const MapEntry('c', {'boardId': 'c', 'visible': true}),
          const MapEntry('d', <String, dynamic>{}), // doc id is the board id
          const MapEntry('x', {'boardId': 'x'}), // not one of the user's boards
        ],
        {'a', 'b', 'c', 'd'},
      );
      expect(ids, ['a', 'c', 'd']);
    },
  );

  test('chunked splits into whereIn-sized batches', () {
    // Firestore's `whereIn` syntax limit is 30.
    expect(chunked(List.generate(65, (i) => i)).map((c) => c.length), [
      30,
      30,
      5,
    ]);
    expect(chunked(List.generate(23, (i) => i)).map((c) => c.length), [23]);
    // Collections whose rules read a document per candidate need 10.
    expect(chunked(List.generate(23, (i) => i), 10).map((c) => c.length), [
      10,
      10,
      3,
    ]);
    expect(chunked(<int>[]), isEmpty);
    expect(() => chunked([1], 0), throwsArgumentError);
  });

  group('combineLatest2', () {
    test('waits for both sources, then emits on either change', () async {
      final a = StreamController<int>();
      final b = StreamController<String>();
      final out = <String>[];
      final sub = combineLatest2(
        a.stream,
        b.stream,
        (int x, String y) => '$x$y',
      ).listen(out.add);

      a.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(out, isEmpty, reason: 'b has not emitted yet');

      b.add('a');
      await Future<void>.delayed(Duration.zero);
      expect(out, ['1a']);

      a.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(out, ['1a', '2a']);

      b.add('b');
      await Future<void>.delayed(Duration.zero);
      expect(out, ['1a', '2a', '2b']);

      await a.close();
      await b.close();
      await sub.cancel();
    });

    test('closes once both sources have closed', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      var done = false;
      final sub = combineLatest2(
        a.stream,
        b.stream,
        (int x, int y) => x + y,
      ).listen((_) {}, onDone: () => done = true);

      a.add(1);
      b.add(2);
      await Future<void>.delayed(Duration.zero);
      await a.close();
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse, reason: 'b is still open');
      await b.close();
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
      await sub.cancel();
    });

    test('forwards source errors', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final errors = <Object>[];
      final sub = combineLatest2(
        a.stream,
        b.stream,
        (int x, int y) => x + y,
      ).listen((_) {}, onError: errors.add);

      b.add(1);
      a.addError(const FormatException('bad'));
      await Future<void>.delayed(Duration.zero);
      expect(errors, hasLength(1));

      await a.close();
      await b.close();
      await sub.cancel();
    });
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
    expect(
      timeAgo(now.subtract(const Duration(seconds: 10)), now: now),
      'just now',
    );
    expect(
      timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      '5m ago',
    );
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
    expect(timeAgo(now.subtract(const Duration(days: 2)), now: now), '2d ago');
    expect(timeAgo(DateTime(2026, 1, 5), now: now), '2026-01-05');
    expect(timeAgo(now.add(const Duration(minutes: 1)), now: now), 'just now');
  });
}
