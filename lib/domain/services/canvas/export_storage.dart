/// Where board exports are written.
///
/// Phones and desktops resolve a writable folder (public Downloads on Android,
/// Documents on iOS/macOS, path_provider's downloads folder elsewhere). The web
/// has no file system — its exports are browser downloads
/// (`BoardExportService.renderCanvasExport` + `saveExportAsDownload`) — so the
/// web build gets a stub instead of a `Platform` check that cannot run in a
/// browser.
library;

export 'export_storage_io.dart'
    if (dart.library.js_interop) 'export_storage_web.dart'
    show resolveExportDirectory;

/// A folder exported files are written to. Only its path is used.
class ExportDirectory {
  final String path;

  const ExportDirectory(this.path);
}
