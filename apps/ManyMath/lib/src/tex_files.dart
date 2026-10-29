import 'dart:convert';

import 'package:file_selector/file_selector.dart';

import 'tex_files_io.dart'
    if (dart.library.js_interop) 'tex_files_web.dart'
    as platform;

const texTypeGroup = XTypeGroup(
  label: 'LaTeX document',
  extensions: <String>['tex'],
  mimeTypes: <String>['text/x-tex', 'application/x-tex', 'text/plain'],
);

typedef ImportedTexDocument = ({String name, String contents});

/// Converts a selected file name into a document title.
String texDocumentName(String fileName) {
  final leafName = fileName.split(RegExp(r'[/\\]')).last.trim();
  final withoutExtension = leafName.replaceFirst(
    RegExp(r'\.tex$', caseSensitive: false),
    '',
  );
  return withoutExtension.trim().isEmpty
      ? 'Imported document'
      : withoutExtension.trim();
}

/// Produces a portable download/save suggestion with exactly one `.tex`
/// extension. The picker remains responsible for the final destination.
String texFileName(String documentName) {
  var safeName = documentName
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-')
      .trim()
      .replaceFirst(RegExp(r'[. ]+$'), '');
  safeName = safeName.replaceFirst(
    RegExp(r'(?:\.tex)+$', caseSensitive: false),
    '',
  );
  if (safeName.isEmpty) safeName = 'Untitled';
  // Windows reserves device names whatever the extension (CON.tex opens the
  // console), so give them a suffix.
  if (RegExp(
    r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])$',
    caseSensitive: false,
  ).hasMatch(safeName)) {
    safeName = '${safeName}_';
  }
  // File systems cap names near 255 bytes; keep whole characters within a
  // margin of that, counted in UTF-8.
  var runes = safeName.runes.toList();
  while (utf8.encode(String.fromCharCodes(runes)).length > _maxNameBytes) {
    runes = runes.sublist(0, runes.length - 1);
  }
  safeName = String.fromCharCodes(runes).trimRight();
  return '$safeName.tex';
}

const _maxNameBytes = 200;

ImportedTexDocument importedTexDocument({
  required String fileName,
  required String contents,
}) {
  return (name: texDocumentName(fileName), contents: contents);
}

/// Decodes the bytes of a `.tex` file. Files are UTF-8 today; older documents
/// written for `\usepackage[latin1]{inputenc}` are Latin-1, which every byte
/// sequence decodes as, so it is the fallback when UTF-8 decoding fails.
String decodeTexBytes(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// Opens a native picker or browser upload control and reads one `.tex` file.
Future<ImportedTexDocument?> openTexFile() async {
  final file = await openFile(
    acceptedTypeGroups: const <XTypeGroup>[texTypeGroup],
  );
  if (file == null) return null;
  return importedTexDocument(
    fileName: file.name,
    contents: decodeTexBytes(await file.readAsBytes()),
  );
}

/// Saves through a native save dialog or a browser download.
Future<String?> saveTexFile(String documentName, String contents) {
  return platform.saveTexFile(
    texFileName(documentName),
    contents,
    texTypeGroup,
  );
}
