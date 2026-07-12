import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/tex_files.dart';

void main() {
  test('derives a title from Windows, POSIX, and uppercase tex names', () {
    expect(texDocumentName(r'C:\notes\Euler.TEX'), 'Euler');
    expect(texDocumentName('/tmp/problem-set.tex'), 'problem-set');
    expect(texDocumentName('.tex'), 'Imported document');
  });

  test('creates a portable filename with exactly one tex extension', () {
    expect(texFileName('Euler.TEX'), 'Euler.tex');
    expect(texFileName('Euler.tex.tex'), 'Euler.tex');
    expect(texFileName('  Problem: Set 1  '), 'Problem- Set 1.tex');
    expect(texFileName(r'../'), 'Untitled.tex');
  });

  test('import helper preserves source verbatim', () {
    const source = '\uFEFF\\section{One}\r\n\$x & y\$';
    final imported = importedTexDocument(
      fileName: 'paper.tex',
      contents: source,
    );
    expect(imported.name, 'paper');
    expect(imported.contents, source);
  });
}
