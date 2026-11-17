import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/ai_feature_flag.dart';

void main() {
  group('isAiImageEnabled', () {
    test('is on only for the value "true" (any case, surrounding spaces)', () {
      expect(isAiImageEnabled({'AI_IMAGE_ENABLED': 'true'}), isTrue);
      expect(isAiImageEnabled({'AI_IMAGE_ENABLED': ' TRUE '}), isTrue);
      expect(isAiImageEnabled({'AI_IMAGE_ENABLED': 'True'}), isTrue);
    });

    test('is off when false, missing, empty or anything else', () {
      expect(isAiImageEnabled({'AI_IMAGE_ENABLED': 'false'}), isFalse);
      expect(isAiImageEnabled(<String, String>{}), isFalse);
      expect(isAiImageEnabled({'AI_IMAGE_ENABLED': ''}), isFalse);
      expect(isAiImageEnabled({'AI_IMAGE_ENABLED': '1'}), isFalse);
      expect(isAiImageEnabled({'AI_IMAGE_ENABLED': 'yes'}), isFalse);
      expect(isAiImageEnabled({'OTHER': 'true'}), isFalse);
    });

    test('is off, without throwing, when .env was never loaded', () {
      dotenv.clean();
      expect(isAiImageEnabled(), isFalse);
    });

    test('reads the loaded .env values by default', () {
      dotenv.loadFromString(envString: 'AI_IMAGE_ENABLED=true');
      expect(isAiImageEnabled(), isTrue);

      dotenv.loadFromString(envString: 'AI_IMAGE_ENABLED=false');
      expect(isAiImageEnabled(), isFalse);

      dotenv.loadFromString(envString: 'SOMETHING_ELSE=1');
      expect(isAiImageEnabled(), isFalse);
      dotenv.clean();
    });
  });
}
