import 'print_io.dart'
    if (dart.library.js_interop) 'print_web.dart'
    as platform;

/// Opens the standalone print/preview window (see `buildPrintHtml`). On
/// non-web builds this throws [UnsupportedError]; callers gate on `kIsWeb`.
void openPrintWindow(String html) => platform.openPrintWindow(html);

/// Where the print window loads the app's bundled fonts from. Fonts are
/// assets under the app's base href (`/edit/`), which the page location
/// only matches when it ends in a slash: `/edit` resolves to `/assets/`.
String printFontBaseUrl() => fontBaseUrlFor(platform.documentBaseUrl());

/// The bundled fonts' directory under the document base URL [base].
String fontBaseUrlFor(String base) =>
    Uri.parse(base).resolve('assets/fonts/').toString();
