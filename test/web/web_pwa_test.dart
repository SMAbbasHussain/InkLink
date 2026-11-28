import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Installability (ranked follow-up: PWA): the Cloud web build must ship a
/// real web app manifest with resolvable, correctly sized icons, link it from
/// `index.html`, and register a minimal service worker so the browser offers
/// to install the app.
void main() {
  final index = File('web/index.html').readAsStringSync();

  /// Width and height from a PNG's IHDR chunk, so the test proves the icon is
  /// a real image of the declared size rather than a renamed placeholder.
  (int, int) pngSize(String path) {
    final bytes = File(path).readAsBytesSync();
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    for (var i = 0; i < signature.length; i++) {
      expect(bytes[i], signature[i], reason: '$path is not a PNG');
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    // 8-byte signature, 4-byte length, 4-byte "IHDR", then width/height.
    return (data.getUint32(16), data.getUint32(20));
  }

  test(
    'index.html links the web app manifest and registers a service worker',
    () {
      expect(
        index,
        contains('rel="manifest"'),
        reason: 'the browser needs a manifest link to offer installation',
      );
      expect(index, contains('manifest.webmanifest'));
      expect(index, isNot(contains('href="manifest.json"')));

      expect(index, contains('sw.js'), reason: 'service worker registration');
      expect(index, contains('serviceWorker'));

      // Open Graph / Twitter share previews must point at an existing icon asset.
      expect(index, contains('content="icons/pwa-512.png"'));
      expect(index, isNot(contains('Icon-512.png')));
      expect(File('web/icons/pwa-512.png').existsSync(), isTrue);

      // Splash CSS must match InkLink's light and dark desk surface colors and
      // avoid locking browser zoom for accessibility.
      expect(index, contains('background-color: #EDEDF0'));
      expect(index, contains('prefers-color-scheme: dark'));
      expect(index, contains('background-color: #121418'));
      expect(index, isNot(contains('user-scalable=no')));
    },
  );

  test(
    'the manifest parses and carries the fields installability requires',
    () {
      final manifestFile = File('web/manifest.webmanifest');
      expect(
        manifestFile.existsSync(),
        isTrue,
        reason:
            'the manifest must exist in the app shell (copied into build/web)',
      );
      final manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;

      expect(manifest['name'], 'InkLink');
      expect(manifest['short_name'], 'InkLink');
      // Standalone installs need a start URL inside the manifest's own scope.
      expect(manifest['start_url'], './');
      expect(manifest['scope'], './');
      expect(manifest['display'], 'standalone');
      // The companion's real colours: accent and the light desk surface.
      expect(manifest['theme_color'], '#6A4EFF');
      expect(manifest['background_color'], '#EDEDF0');
      expect(
        manifest['description'],
        isA<String>().having((d) => d.trim(), 'not empty', isNotEmpty),
      );
    },
  );

  test(
    'every declared icon exists, is a PNG, and matches its declared size',
    () {
      final manifest =
          jsonDecode(File('web/manifest.webmanifest').readAsStringSync())
              as Map<String, dynamic>;
      final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
      expect(icons, isNotEmpty);

      final purposes = <String>{};
      for (final icon in icons) {
        final src = icon['src'] as String;
        final sizes = icon['sizes'] as String;
        expect(icon['type'], 'image/png', reason: '$src type');
        final file = File('web/$src');
        expect(
          file.existsSync(),
          isTrue,
          reason: '$src is not in the app shell',
        );

        final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(sizes);
        expect(match, isNotNull, reason: '$src sizes');
        final declared = (
          int.parse(match!.group(1)!),
          int.parse(match.group(2)!),
        );
        expect(pngSize('web/$src'), declared, reason: '$src pixel size');

        for (final purpose in (icon['purpose'] as String? ?? 'any').split(
          ' ',
        )) {
          purposes.add(purpose);
        }
      }

      expect(purposes, contains('any'));
      expect(purposes, contains('maskable'));
      // Android/Chrome installs want both sizes for each purpose.
      expect(
        icons.where((i) => (i['sizes'] as String).startsWith('192')).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        icons.where((i) => (i['sizes'] as String).startsWith('512')).length,
        greaterThanOrEqualTo(2),
      );
    },
  );

  test('the service worker is minimal but has a fetch handler', () {
    final sw = File('web/sw.js');
    expect(sw.existsSync(), isTrue);
    final body = sw.readAsStringSync();
    expect(body, contains("addEventListener('install'"));
    expect(body, contains("addEventListener('fetch'"));
    // Never cache the app shell blindly: a stale bundle would ship old code.
    expect(body, isNot(contains('caches.addAll')));
  });
}
