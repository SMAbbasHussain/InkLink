import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/web/domain/models/web_account_settings.dart';

void main() {
  group('WebAccountSettings.fromMap', () {
    test('missing document uses the phone defaults', () {
      expect(WebAccountSettings.fromMap(null), WebAccountSettings.defaults);
      expect(WebAccountSettings.fromMap({}), WebAccountSettings.defaults);
      const defaults = WebAccountSettings.defaults;
      expect(defaults.isProfilePublic, isTrue);
      expect(defaults.showOnlineStatus, isTrue);
      expect(defaults.showEmail, isFalse);
      expect(defaults.preferredTags, isEmpty);
    });

    test('reads the fields the phone writes', () {
      final settings = WebAccountSettings.fromMap({
        'isProfilePublic': false,
        'showOnlineStatus': false,
        'showEmail': true,
        'preferredTags': ['Design', 'Music'],
      });
      expect(settings.isProfilePublic, isFalse);
      expect(settings.showOnlineStatus, isFalse);
      expect(settings.showEmail, isTrue);
      expect(settings.preferredTags, ['Design', 'Music']);
    });

    test('trims tags and drops blanks and non-strings', () {
      final settings = WebAccountSettings.fromMap({
        'preferredTags': ['  Design  ', '', 42, null, 'Music '],
      });
      expect(settings.preferredTags, ['Design', 'Music']);
    });

    test('a non-list preferredTags value is ignored', () {
      final settings = WebAccountSettings.fromMap({'preferredTags': 'Design'});
      expect(settings.preferredTags, isEmpty);
    });
  });

  test('privacyFields writes exactly the three booleans', () {
    const settings = WebAccountSettings(
      isProfilePublic: false,
      showOnlineStatus: true,
      showEmail: true,
    );
    expect(settings.privacyFields(), {
      'isProfilePublic': false,
      'showOnlineStatus': true,
      'showEmail': true,
    });
  });

  group('toggleTag', () {
    test('adds a new tag at the end', () {
      expect(WebAccountSettings.toggleTag(['Design'], 'Music'), [
        'Design',
        'Music',
      ]);
    });

    test('removes an existing tag, ignoring case and spaces', () {
      expect(WebAccountSettings.toggleTag(['Design', 'Music'], ' design '), [
        'Music',
      ]);
    });

    test('keeps the order of the remaining tags', () {
      expect(
        WebAccountSettings.toggleTag(['Art', 'Design', 'Music'], 'DESIGN'),
        ['Art', 'Music'],
      );
    });

    test('ignores blank input and never mutates the input list', () {
      final tags = ['Design'];
      expect(WebAccountSettings.toggleTag(tags, '   '), ['Design']);
      expect(WebAccountSettings.toggleTag(tags, 'Music'), ['Design', 'Music']);
      expect(tags, ['Design']);
    });
  });

  group('copyWith', () {
    test('replaces only the given fields', () {
      const original = WebAccountSettings(preferredTags: ['Art']);
      final next = original.copyWith(showEmail: true);
      expect(next.showEmail, isTrue);
      expect(next.isProfilePublic, original.isProfilePublic);
      expect(next.showOnlineStatus, original.showOnlineStatus);
      expect(next.preferredTags, ['Art']);
    });

    test('keeps the original tags when they are not replaced', () {
      const original = WebAccountSettings(preferredTags: ['Art']);
      expect(original.copyWith(showEmail: false).preferredTags, ['Art']);
    });
  });

  test('equality compares the tag list by content', () {
    expect(
      const WebAccountSettings(preferredTags: ['Art']),
      const WebAccountSettings(preferredTags: ['Art']),
    );
    expect(
      const WebAccountSettings(preferredTags: ['Art']).hashCode,
      const WebAccountSettings(preferredTags: ['Art']).hashCode,
    );
    expect(
      const WebAccountSettings(preferredTags: ['Art']),
      isNot(const WebAccountSettings(preferredTags: ['Design'])),
    );
  });
}
