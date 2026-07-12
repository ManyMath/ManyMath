import 'dart:js_interop';

import 'package:file_selector/file_selector.dart';
import 'package:web/web.dart' as web;

Future<String?> saveTexFile(
  String fileName,
  String contents,
  XTypeGroup _,
) async {
  final blob = web.Blob(
    <JSString>[contents.toJS].toJS,
    web.BlobPropertyBag(type: 'application/x-tex;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    web.URL.revokeObjectURL(url);
  }
  return fileName;
}
