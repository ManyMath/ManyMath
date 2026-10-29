import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/problem_export.dart';

const _exercises = r'''
\documentclass{book}
\begin{document}
\section*{Differentiation}

\Exercises{I} (See answers.)

Differentiate the following:
\begin{Problems}[2]
\Item{(1)} $y = x^{13}$
\Item{(2)} $y = x^{-3}$

\Item{(3)} Find the slope of $y = x^2$ at $x = 3$, where
\[
  y' = 2x.
\]
\end{Problems}

\section*{Answers}

\begin{Answers}{I}{}{}
\Item{(1)} $13x^{12}$.
\Item{(2)} $-3x^{-4}$.
\end{Answers}
\end{document}
''';

void main() {
  test('pairs exercises with the answers of the same set and number', () {
    final export = extractProblems(_exercises, file: 'book.tex', book: 'calc');
    expect(export.items.map((i) => i.number), ['1', '2', '3']);
    expect(export.items.map((i) => i.kind).toSet(), {'exercise'});
    expect(export.items.first.section, 'Exercises I');
    expect(export.items.first.statementTex, r'$y = x^{13}$');
    expect(export.items.first.answerTex, r'$13x^{12}$.');
    expect(export.items[1].answerTex, r'$-3x^{-4}$.');
    expect(export.items[2].answerTex, isNull);
    expect(export.answers, 2);
    expect(export.unmatched, 0);
  });

  test('keeps continuation text and display math with the item', () {
    final item = extractProblems(_exercises, book: 'calc').items[2];
    expect(item.statementTex, contains('Find the slope of'));
    expect(item.statementTex, contains("\\[y' = 2x.\\]"));
    expect(item.formulas, contains('y = x^2'));
  });

  test('formulas list statement then answer formulas', () {
    final item = extractProblems(_exercises, book: 'calc').items.first;
    expect(item.formulas, ['y = x^{13}', '13x^{12}']);
  });

  test('records the source line and a stable id', () {
    final item = extractProblems(_exercises, file: 'a/b.tex').items[1];
    expect(item.line, 10);
    expect(item.file, 'a/b.tex');
    expect(item.id, 'b_i_2_exercise');
    final ids = extractProblems(_exercises).items.map((i) => i.id);
    expect(ids.toSet(), hasLength(3));
  });

  test('exports theorems and propositions with their numbers', () {
    const tex = r'''
\begin{document}
\section{Limits}
\begin{theorem}
If $a_n \to a$ then $a_n^2 \to a^2$.
\end{theorem}
\begin{proposition}
Every convergent sequence is bounded.
\end{proposition}
\begin{definition}
A sequence is bounded if...
\end{definition}
\begin{proof}
Trivial.
\end{proof}
\end{document}
''';
    final items = extractProblems(tex, book: 'an').items;
    expect(items.map((i) => i.kind), ['theorem', 'proposition']);
    expect(items.map((i) => i.number), ['1', '1']);
    expect(items.first.section, 'Limits');
    expect(items.first.formulas, ['a_n \\to a', 'a_n^2 \\to a^2']);
    expect(items.first.answerTex, isNull);
  });

  test('exports worked examples from an Examples block', () {
    const tex = r'''
\begin{document}
\section{Rules}
\begin{Examples}{1}
\Item{(1)} Differentiate $y = a x^3$.
\end{Examples}
\end{document}
''';
    final items = extractProblems(tex, book: 'calc').items;
    expect(items, hasLength(1));
    expect(items.single.kind, 'example');
    expect(items.single.statementTex, r'Differentiate $y = a x^3$.');
  });

  test('document header carries generator, source file and count', () {
    final export = extractProblems(_exercises, file: 'book.tex');
    final doc = exportDocument(export, 'book.tex');
    expect(doc['generator'], isNotEmpty);
    expect(doc['source_file'], 'book.tex');
    expect(doc['count'], 3);
    final first = (doc['items'] as List).first as Map<String, Object?>;
    expect(first.keys, [
      'id',
      'book',
      'section',
      'number',
      'kind',
      'statement_tex',
      'answer_tex',
      'formulas',
      'source',
    ]);
    expect(first['source'], {'file': 'book.tex', 'line': 9});
  });

  test('a document without problems exports nothing', () {
    final export = extractProblems(r'\begin{document}Hello $x$.\end{document}');
    expect(export.items, isEmpty);
  });

  group('set boundaries', () {
    test('a list after an Examples block is not part of the set', () {
      const src = r'''
\begin{document}
\section*{Chapter}
\begin{Examples}{XX}
\Item{1.} Prove that $x = 1$.
\Item{2.} Show that $y = 2$.
\end{Examples}

Then we prove in succession:

\Item{(1)} that the remainder is $f(a)$;

\Item{(2)} that $a$ is a root.
\end{document}
''';
      final export = extractProblems(src, book: 'h');
      expect(export.items.map((i) => i.number), ['1', '2']);
      expect(
        export.items.map((i) => i.statementTex).join(),
        isNot(contains('remainder')),
      );
      expect(export.warnings, isEmpty);
    });

    test('a numbered paragraph ends an \\Exercise set', () {
      const src = r'''
\begin{document}
\Exercise{2.}

Combine:
\Item{1.} $a + a$.

\Item{2.} $b + b$.

\Paragraph{40.} The value of an expression is found by substitution.

\Item{1.} If $b = 4$, find $3b^{2}$.
\begin{Soln}
Here $3b^{2} = 48$.
\end{Soln}
\end{document}
''';
      final export = extractProblems(src, book: 'w');
      expect(export.items.map((i) => i.number), ['1', '2']);
      expect(export.items.map((i) => i.id).toSet().length, 2);
      expect(export.items.first.statementTex, r'$a + a$.');
    });

    test('\\Answers (the answer section) ends an \\Exercise set', () {
      const src = r'''
\begin{document}
\Exercise{1.}
\Item{1.} $a$.

\Answers
\Item{1.} $b$.
\end{document}
''';
      expect(extractProblems(src, book: 'w').items.length, 1);
    });

    test('a heading before the first item still names the set', () {
      const src = r'''
\begin{document}
\Exercise{3.}
\section*{Miscellaneous}
\Item{1.} $a$.
\Item{2.} $b$.
\end{document}
''';
      expect(extractProblems(src, book: 'w').items.length, 2);
    });
  });

  group('unique ids', () {
    const twice = r'''
\begin{document}
\begin{Examples}{I}
\Item{1.} $a$.
\end{Examples}
\begin{Examples}{I}
\Item{1.} $b$.
\end{Examples}
\end{document}
''';

    test('a repeated set label keeps both items under distinct ids', () {
      final export = extractProblems(twice, book: 'b');
      expect(export.items.length, 2);
      expect(export.items.map((i) => i.id).toSet().length, 2);
      expect(export.warnings, ['repeated id b_i_1_example (occurrence 2)']);
    });

    test('a repeated answer key is reported and the first one wins', () {
      const src = r'''
\begin{document}
\Exercises{I}
\begin{Problems}
\Item{(1)} $a$.
\end{Problems}
\begin{Answers}{I}{}{}
\Item{(1)} $first$.
\Item{(1)} $second$.
\end{Answers}
\end{document}
''';
      final export = extractProblems(src, book: 'b');
      expect(export.items.single.answerTex, r'$first$.');
      expect(export.warnings.single, startsWith('repeated answer key I#1'));
    });
  });

  group('answers printed in the text', () {
    test('a run-on answer after \\hfil (12) is its own answer', () {
      const src = r'''
\begin{document}
\Exercises{II}
\begin{Problems}
\Item{(11)} Find $a$.

\Item{(12)} Find $b$.
\end{Problems}
\begin{Answers}{II}{}{}
\Item{(11)} $2\pi$, $2\pi r$. \hfil
(12)~$\dfrac{dD}{dT}$.
\end{Answers}
\end{document}
''';
      final export = extractProblems(src, book: 't');
      expect(export.items.map((i) => i.answerTex), [
        r'$2\pi$, $2\pi r$.',
        r'$\dfrac{dD}{dT}$.',
      ]);
      expect(export.unmatched, 0);
    });

    test('an Ans. line inside the statement becomes the answer', () {
      const src = r'''
\begin{document}
\Exercises{V}
\begin{Problems}
\Item{(1)} If $y = a + bt^2$; find $\dfrac{dy}{dt}$.
\[
\text{\textit{Ans.} $\dfrac{dy}{dt} = 2bt$.}
\]

\Item{(2)} Next $z$.
\end{Problems}
\end{document}
''';
      final items = extractProblems(src, book: 't').items;
      expect(items[0].answerTex, r'$\dfrac{dy}{dt} = 2bt$.');
      expect(items[0].statementTex, isNot(contains('Ans')));
      expect(items[0].formulas, contains(r'\dfrac{dy}{dt} = 2bt'));
      expect(items[1].answerTex, isNull);
    });

    test('AnsTo answers section pairs by exercise and item number', () {
      const src = r'''
\begin{document}
\Exercise{1.}
Simplify:
\begin{multicols}{2}
\Item{1.}  $9 + (3 + 2)$.

\Item{2.}  $9 + (3 - 2)$.

\Item{3.}  $7 + 5$.
\end{multicols}

\Exercise{2.}

\Item{1.}  Write six increased by four. \Ans{$6 + 4$.}

\Item{2.}  Write $a$ increased by~$b$.

\Answers

\AnsTo[7]{Exercise}{1.} %  Page 10.

\Item{1.}  $14$.

\Item{2.}  $10$.

\AnsTo[5]{Exercise}{2.}

\Item{2.}  $a + b$.

\Item{9.}  $0$.
\BackMatter
\end{document}
''';
      final export = extractProblems(src, book: 'w');
      final byId = {for (final i in export.items) i.id: i};
      expect(byId['w_1_1_exercise']!.answerTex, r'$14$.');
      expect(byId['w_1_2_exercise']!.answerTex, r'$10$.');
      expect(byId['w_1_3_exercise']!.answerTex, isNull);
      expect(byId['w_2_2_exercise']!.answerTex, r'$a + b$.');
      expect(byId['w_2_2_exercise']!.formulas, contains('a + b'));
      expect(export.answers, 4);
      expect(export.unmatched, 1);
      expect(export.warnings, isEmpty);
    });

    test('inline Ans is the fallback and stays out of the statement', () {
      const src = r'''
\begin{document}
\Exercise{2.}

\Item{1.}  Write six increased by four. \Ans{$6 + 4$.}

\Item{2.}  Write $a$ increased by~$b$.
\end{document}
''';
      final items = extractProblems(src, book: 'w').items;
      expect(items[0].answerTex, r'$6 + 4$.');
      expect(items[0].statementTex, isNot(contains('Ans')));
      expect(items[0].statementTex, contains('six increased'));
      expect(items[1].answerTex, isNull);
    });
  });
}
