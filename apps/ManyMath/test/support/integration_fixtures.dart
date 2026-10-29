import 'dart:io';

File integrationFixture(String relativePath) {
  for (final base in [
    'test/fixtures/integration',
    'apps/ManyMath/test/fixtures/integration',
  ]) {
    final file = File('$base/$relativePath');
    if (file.existsSync()) return file;
  }
  throw StateError('Missing owned integration fixture: $relativePath');
}

File? nativeRatexLibrary() {
  final path = Platform.environment['RATEX_LIB'];
  if (path == null || path.isEmpty) return null;
  final library = File(path);
  if (!library.existsSync()) {
    throw StateError('RATEX_LIB does not identify a built renderer: $path');
  }
  return library;
}
