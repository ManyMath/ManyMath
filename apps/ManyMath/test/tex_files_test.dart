import 'dart:convert';

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

  test('avoids Windows device names and over-long names', () {
    expect(texFileName('CON'), 'CON_.tex');
    expect(texFileName('nul.tex'), 'nul_.tex');
    expect(texFileName('com1'), 'com1_.tex');
    expect(texFileName('Console'), 'Console.tex');
    final long = texFileName('é' * 300);
    expect(utf8.encode(long).length, lessThanOrEqualTo(204));
    expect(long, endsWith('é.tex'), reason: 'whole characters only');
  });

  test('decodes UTF-8, dropping a BOM, and falls back to Latin-1', () {
    expect(decodeTexBytes([0xef, 0xbb, 0xbf, 0x41]), 'A');
    expect(decodeTexBytes('caf\u00e9'.codeUnits), 'caf\u00e9');
    expect(decodeTexBytes([0x5c, 0xe9, 0x74, 0xe9]), '\\\u00e9t\u00e9');
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
