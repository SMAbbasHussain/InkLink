import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/services/board/board_service.dart';

void main() {
  group('normalizeBoardJoinCode', () {
    test('trims surrounding whitespace', () {
      expect(normalizeBoardJoinCode('  AbC123xyz  '), 'AbC123xyz');
    });

    test('keeps a plain document id unchanged', () {
      expect(normalizeBoardJoinCode('Kq3v9XyZ12abcdEF34gh'), 'Kq3v9XyZ12abcdEF34gh');
    });

    test('extracts the code from a board deep link', () {
      expect(
        normalizeBoardJoinCode('https://inklink.app/board/Kq3v9XyZ12abcdEF34gh'),
        'Kq3v9XyZ12abcdEF34gh',
      );
    });

    test('drops query strings and fragments from a pasted link', () {
      expect(
        normalizeBoardJoinCode(
          'https://inklink.app/board/Kq3v9XyZ12abcdEF34gh?invite=1#top',
        ),
        'Kq3v9XyZ12abcdEF34gh',
      );
    });

    test('handles a trailing slash', () {
      expect(
        normalizeBoardJoinCode('https://inklink.app/board/Kq3v9XyZ12abcdEF34gh/'),
        'Kq3v9XyZ12abcdEF34gh',
      );
    });

    test('returns an empty string for empty input', () {
      expect(normalizeBoardJoinCode('   '), '');
    });
  });
}
