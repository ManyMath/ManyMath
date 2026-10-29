import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Opens [html] in a new tab and raises the browser print dialog there.
/// The tab doubles as the print preview and stays open after the dialog;
/// the dialog's "Save as PDF" is the PDF export path.
void openPrintWindow(String html) {
  final win = web.window.open('', '_blank');
  if (win == null) {
    throw StateError(
      'The browser blocked the print window. Allow pop-ups for this site '
      'and try again.',
    );
  }
  final doc = win.document;
  doc.open();
  doc.write(html.toJS);
  doc.close();

  // The toolbar button is wired from here rather than an inline script, so
  // a strict Content-Security-Policy on the host page cannot block it.
  doc
      .getElementById('manymath-print')
      ?.addEventListener('click', ((web.Event _) => win.print()).toJS);

  // Raise the print dialog once the fonts settle; on any failure (the tab
  // was closed first, or a dialog is already open) the toolbar button
  // remains as the manual path.
  unawaited(
    win.document.fonts.ready.toDart
        .then((_) => win.print())
        .catchError((Object _) {}),
  );
}

/// The document's base URL, which honours `<base href>` where the page
/// location does not.
String documentBaseUrl() => web.document.baseURI;
