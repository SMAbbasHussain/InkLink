/// The folders board export writes to.
///
/// Phones get path_provider's functions unchanged. The web build (no file
/// system; exports are browser downloads) gets stubs that return null, so
/// path_provider stays out of the web build.
library;

export 'package:path_provider/path_provider.dart'
    if (dart.library.js_interop) 'export_directories_web.dart'
    show
        getApplicationDocumentsDirectory,
        getDownloadsDirectory,
        getExternalStorageDirectory;
