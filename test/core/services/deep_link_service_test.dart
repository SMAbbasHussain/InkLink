import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/services/deep_link_service.dart';

void main() {
  late DeepLinkService deepLinkService;

  setUp(() {
    deepLinkService = DeepLinkService.instance;
    deepLinkService.setPendingBoardId(null);
  });

  group('DeepLinkService URI Parsing', () {
    test('extracts boardId from custom scheme inklink://board/:id', () {
      final boardId =
          deepLinkService.extractBoardId('inklink://board/abc-123-xyz');
      expect(boardId, equals('abc-123-xyz'));
    });

    test('extracts boardId from custom scheme with three slashes', () {
      final boardId =
          deepLinkService.extractBoardId('inklink:///board/board_999');
      expect(boardId, equals('board_999'));
    });

    test('extracts boardId from https web app link', () {
      final boardId = deepLinkService
          .extractBoardId('https://inklink.web.app/board/board_alpha');
      expect(boardId, equals('board_alpha'));
    });

    test('extracts boardId from https custom domain link', () {
      final boardId =
          deepLinkService.extractBoardId('https://inklink.app/board/board_beta');
      expect(boardId, equals('board_beta'));
    });

    test('extracts boardId from relative path', () {
      final boardId = deepLinkService.extractBoardId('/board/board_delta');
      expect(boardId, equals('board_delta'));
    });

    test('strips trailing slashes, fragments, and query parameters', () {
      final boardId = deepLinkService
          .extractBoardId('inklink://board/board_omega/?role=viewer#top');
      expect(boardId, equals('board_omega'));
    });

    test('returns null for null, empty or invalid non-board paths', () {
      expect(deepLinkService.extractBoardId(null), isNull);
      expect(deepLinkService.extractBoardId(''), isNull);
      expect(deepLinkService.extractBoardId('inklink://settings'), isNull);
      expect(deepLinkService.extractBoardId('https://inklink.app/about'), isNull);
    });
  });

  group('DeepLinkService Pending Board Management', () {
    test('setPendingBoardId and consumePendingBoardId work properly', () {
      deepLinkService.setPendingBoardId('pending_board_77');
      expect(deepLinkService.pendingBoardId, equals('pending_board_77'));

      final consumed = deepLinkService.consumePendingBoardId();
      expect(consumed, equals('pending_board_77'));
      expect(deepLinkService.pendingBoardId, isNull);
    });
  });
}
