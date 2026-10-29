import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/formula_check.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manymath/src/templates.dart';
import 'package:ratex/ratex.dart';

import 'support/integration_fixtures.dart';

void main() {
  final library = nativeRatexLibrary();
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

  test('rewritten display environments compile and map errors back', () {
    const valid = r'''
\begin{multline*}
a + b \\
+ c
\end{multline*}
\begin{eqnarray}
x & = & \frac{1}{2} \\
y & \le & 3
\end{eqnarray}
\begin{flalign*}
p &= q
\end{flalign*}
''';
    expect(checkFormulas(parseLatexDocument(valid)), isEmpty);

    const broken =
        'Before.\n\\begin{eqnarray}\nx & = & \\frac{1}{\n'
        '\\end{eqnarray}\nAfter.';
    final issues = checkFormulas(parseLatexDocument(broken));
    expect(issues, hasLength(1));
    final selection = issues.single.selection!;
    expect(selection.$1, greaterThanOrEqualTo(broken.indexOf(r'\begin')));
    expect(selection.$2, lessThanOrEqualTo(broken.indexOf('After.')));
  }, skip: skip);

  test('formulas using declared math operators compile', () {
    const source = r'''
\DeclareMathOperator{\negl}{negl}
\DeclareMathOperator*{\argmax}{arg\,max}
\begin{document}
A function $f(n) \le \negl(n)$ and \[ \argmax_{x \in S} g(x) \]
\end{document}
''';
    expect(
      checkFormulas(
        parseLatexDocument(source),
        macroPreamble: extractMacroPreamble(source),
      ),
      isEmpty,
    );
  }, skip: skip);

  test('an error beside a citation still selects its source', () {
    const source = r'''
\begin{document}
As in \cite{k}, $\frac{1}{$ fails.
\begin{thebibliography}{9}
\bibitem{k} Someone. 2020.
\end{thebibliography}
\end{document}
''';
    final issues = checkFormulas(parseLatexDocument(source));
    expect(issues, hasLength(1));
    final selection = issues.single.selection;
    expect(selection, isNotNull);
    final start = source.indexOf(r'$\frac{1}{$');
    expect(selection!.$1, greaterThanOrEqualTo(start));
    expect(selection.$2, lessThanOrEqualTo(start + r'$\frac{1}{$'.length));
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

  test('a formula using the document\'s own macro needs the preamble', () {
    // Display math, not inline: parseLatexDocument's own prose-macro
    // expansion (see latex_document_test.dart) already resolves a macro
    // like this one inside inline ($...$) math before RaTeX ever sees it,
    // which would make this case pass regardless of macroPreamble. Display
    // math bypasses that pass entirely, so it still isolates what
    // macroPreamble (RaTeX's own expander) is responsible for.
    const source = r'''
\newcommand{\Fq}{\mathbb{F}_q}
\begin{document}
\[\Fq\]
\end{document}
''';
    final blocks = parseLatexDocument(source);

    expect(checkFormulas(blocks), hasLength(1));
    expect(
      checkFormulas(blocks, macroPreamble: extractMacroPreamble(source)),
      isEmpty,
    );
  }, skip: skip);

  test('a genuine error inside a macro-aware formula still maps to it', () {
    const source = r'''
\newcommand{\Fq}{\mathbb{F}_q}
\begin{document}
fine \[\Fq\] then \[\Fq + \oops\] trailing
\end{document}
''';
    final blocks = parseLatexDocument(source);

    final issues = checkFormulas(
      blocks,
      macroPreamble: extractMacroPreamble(source),
    );

    expect(issues, hasLength(1));
    final selection = issues.single.selection;
    expect(selection, isNotNull);
    final constructStart = source.indexOf(r'\[\Fq + \oops\]');
    expect(selection!.$1, greaterThanOrEqualTo(constructStart));
    expect(
      selection.$2,
      lessThanOrEqualTo(constructStart + r'\[\Fq + \oops\]'.length),
    );
  }, skip: skip);
}
