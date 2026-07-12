import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/formula_check.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manymath/src/templates.dart';
import 'package:ratex_flutter/ratex_flutter.dart';

void main() {
  final libraryName = Platform.isMacOS
      ? 'libratex_ffi.dylib'
      : Platform.isWindows
      ? 'ratex_ffi.dll'
      : 'libratex_ffi.so';
  final library = <String>[
    '../ratex/native/ratex-ffi/target/debug/$libraryName',
    '../ratex/native/ratex-ffi/target/release/$libraryName',
    '../../../ratex/native/ratex-ffi/target/debug/$libraryName',
    '../../../ratex/native/ratex-ffi/target/release/$libraryName',
  ].map(File.new).where((file) => file.existsSync()).firstOrNull;
  final skip = library == null ? 'native ratex_ffi not built' : false;

  setUpAll(() async {
    if (library == null) return;
    Ratex.nativeLibraryPath = library.absolute.path;
    await Ratex.ensureInitialized();
  });

  test('a rejected formula has a clickable source selection', () {
    const source = r'fine $x^2$ then $\frac{1}{$ trailing';

    final issues = checkFormulas(parseLatexDocument(source));

    expect(issues, hasLength(1));
    final selection = issues.single.selection;
    expect(selection, isNotNull);
    final constructStart = source.indexOf(r'$\frac{1}{$');
    expect(selection!.$1, greaterThanOrEqualTo(constructStart));
    expect(
      selection.$2,
      lessThanOrEqualTo(constructStart + r'$\frac{1}{$'.length),
    );
  }, skip: skip);

  test('a live error is not mapped into a preceding comment', () {
    const source = '\$\$ % x+\\oops\nx+\\oops \$\$';

    final issue = checkFormulas(parseLatexDocument(source)).single;

    final liveStart = source.indexOf('x+\\oops', source.indexOf('\n'));
    expect(issue.selection, isNotNull);
    expect(issue.selection!.$1, greaterThanOrEqualTo(liveStart));
    expect(issue.selection!.$2, lessThanOrEqualTo(source.length));
  }, skip: skip);

  test('a metadata error maps back to the title source', () {
    const source = r'''
\title{A bad $\oops$ title}
\begin{document}
\maketitle
\end{document}
''';

    final issue = checkFormulas(parseLatexDocument(source)).single;

    expect(issue.selection, isNotNull);
    final constructStart = source.indexOf(r'$\oops$');
    expect(issue.selection!.$1, greaterThanOrEqualTo(constructStart));
    expect(
      issue.selection!.$2,
      lessThanOrEqualTo(constructStart + r'$\oops$'.length),
    );
  }, skip: skip);

  test('every built-in template passes engine validation', () {
    for (final template in documentTemplates) {
      final issues = checkFormulas(parseLatexDocument(template.source));
      expect(
        issues,
        isEmpty,
        reason:
            '${template.name}: '
            '${issues.map((issue) => issue.message).join('; ')}',
      );
    }
  }, skip: skip);
}
