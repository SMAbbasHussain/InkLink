import 'dart:io';

/// Web stand-ins for path_provider (see export_directories.dart). The web
/// has no folders to save into, so these are never meant to be reached.
Future<Directory> getApplicationDocumentsDirectory() =>
    throw UnsupportedError('No documents folder on the web.');

Future<Directory?> getDownloadsDirectory() async => null;

Future<Directory?> getExternalStorageDirectory() async => null;
