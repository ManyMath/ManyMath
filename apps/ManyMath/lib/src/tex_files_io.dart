import 'dart:io';

import 'package:file_selector/file_selector.dart';

Future<String?> saveTexFile(
  String fileName,
  String contents,
  XTypeGroup typeGroup,
) async {
  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: <XTypeGroup>[typeGroup],
  );
  if (location == null) return null;
  await File(location.path).writeAsString(contents, flush: true);
  return location.path;
}
