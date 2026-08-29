import 'print_io.dart' if (dart.library.js_interop) 'print_web.dart'
    as platform;

/// Opens the standalone print/preview window (see `buildPrintHtml`). On
/// non-web builds this throws [UnsupportedError]; callers gate on `kIsWeb`.
void openPrintWindow(String html) => platform.openPrintWindow(html);
