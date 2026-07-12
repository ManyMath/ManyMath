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
  return '$safeName.tex';
}

ImportedTexDocument importedTexDocument({
  required String fileName,
  required String contents,
}) {
  return (name: texDocumentName(fileName), contents: contents);
}

/// Opens a native picker or browser upload control and reads one `.tex` file.
Future<ImportedTexDocument?> openTexFile() async {
  final file = await openFile(
    acceptedTypeGroups: const <XTypeGroup>[texTypeGroup],
  );
  if (file == null) return null;
  return importedTexDocument(
    fileName: file.name,
    contents: await file.readAsString(),
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
