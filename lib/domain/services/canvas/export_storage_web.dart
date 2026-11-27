import 'export_storage.dart';

/// The browser has no export folder; web exports are downloads built by
/// `renderCanvasExport` and handed to `saveExportAsDownload`.
Future<ExportDirectory> resolveExportDirectory() => throw UnsupportedError(
  'The web has no export folder. Use renderCanvasExport and '
  'saveExportAsDownload instead.',
);
