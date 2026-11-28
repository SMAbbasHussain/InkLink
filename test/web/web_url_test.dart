import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/web/data/web_url.dart';

void main() {
  group('parseWebLocation', () {
    test('the root path names no section', () {
      for (final path in [null, '', '/', '   ', '#']) {
        final location = parseWebLocation(path);
        expect(location.sectionName, isNull, reason: '$path');
        expect(location.boardId, isNull, reason: '$path');
      }
    });

    test('every section route is recognised', () {
      for (final section in webSections) {
        expect(parseWebLocation('/$section').sectionName, section);
        expect(parseWebLocation('#/$section').sectionName, section);
        expect(parseWebLocation('/$section/').sectionName, section);
      }
    });

    test('query strings and trailing slashes are ignored', () {
      expect(parseWebLocation('/friends?tab=blocked').sectionName, 'friends');
      expect(
        parseWebLocation('#/notifications?from=push').sectionName,
        'notifications',
      );
    });

    test('board deep links carry the board id', () {
      final location = parseWebLocation('/board/abc123');
      expect(location.boardId, 'abc123');
      expect(location.sectionName, 'boards');
    });

    test('hash board deep links (the form a static host serves)', () {
      final location = parseWebLocation('#/board/board-42');
      expect(location.boardId, 'board-42');
      expect(location.sectionName, 'boards');
      expect(parseWebLocation('/#/board/x').boardId, 'x');
      expect(parseWebLocation('/board/x?from=link').boardId, 'x');
    });

    test('a full URL is reduced to its path', () {
      expect(
        parseWebLocation('https://inklink.app/#/board/abc').boardId,
        'abc',
      );
    });

    test('/board with no id opens the boards section only', () {
      final location = parseWebLocation('/board');
      expect(location.boardId, isNull);
      expect(location.sectionName, 'boards');
    });

    test('unknown paths fall back to the default section', () {
      final location = parseWebLocation('/something/else');
      expect(location.sectionName, isNull);
      expect(location.boardId, isNull);
    });

    test('section names are case-insensitive', () {
      expect(parseWebLocation('/DISCOVER').sectionName, 'discover');
      expect(parseWebLocation('/Board/xyz').boardId, 'xyz');
    });
  });
}
