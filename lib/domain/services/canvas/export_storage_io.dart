import 'dart:io';

import 'export_directories.dart';
import 'export_storage.dart';

/// A writable folder for exports: the public Downloads/Documents folder on
/// Android when it is usable, the app's Documents folder on iOS/macOS, the
/// downloads folder where the platform has one, and the app documents folder
/// otherwise.
Future<ExportDirectory> resolveExportDirectory() async {
  if (Platform.isAndroid) {
    // 1. Try public Android Download directory
    for (final publicPath in [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
    ]) {
      try {
        final publicDir = Directory(publicPath);
        if (await publicDir.exists()) {
          final inkLinkDir = Directory('${publicDir.path}/InkLink');
          if (!await inkLinkDir.exists()) {
            try {
              await inkLinkDir.create(recursive: true);
            } catch (_) {}
          }
          final targetDir = (await inkLinkDir.exists())
              ? inkLinkDir
              : publicDir;
          // Only an actually writable folder is used.
          final testFile = File(
            '${targetDir.path}/.test_${DateTime.now().millisecondsSinceEpoch}',
          );
          await testFile.writeAsString('test');
          await testFile.delete();
          return ExportDirectory(targetDir.path);
        }
      } catch (_) {}
    }

    // 3. Fallback to external storage directory
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final inkLinkDir = Directory('${extDir.path}/InkLink');
        if (!await inkLinkDir.exists()) {
          await inkLinkDir.create(recursive: true);
        }
        return ExportDirectory(inkLinkDir.path);
      }
    } catch (_) {}
  }

  if (Platform.isIOS || Platform.isMacOS) {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final inkLinkDir = Directory('${docsDir.path}/InkLink');
      if (!await inkLinkDir.exists()) {
        await inkLinkDir.create(recursive: true);
      }
      return ExportDirectory(inkLinkDir.path);
    } catch (_) {}
  }

  try {
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      final inkLinkDir = Directory('${downloadsDir.path}/InkLink');
      if (!await inkLinkDir.exists()) {
        await inkLinkDir.create(recursive: true);
      }
      return ExportDirectory(inkLinkDir.path);
    }
  } catch (_) {}

  final appDocDir = await getApplicationDocumentsDirectory();
  final inkLinkDir = Directory('${appDocDir.path}/InkLink');
  if (!await inkLinkDir.exists()) {
    await inkLinkDir.create(recursive: true);
  }
  return ExportDirectory(inkLinkDir.path);
}
