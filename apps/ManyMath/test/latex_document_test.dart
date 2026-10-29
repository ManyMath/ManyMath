import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manymath/src/papers/frostlass_thresholdization.dart';

/// Every inline span reachable from [blocks], in document order — a
/// convenience for tests that assert over the text/math of nested block
/// structures (list items, quote bodies, theorem bodies).
Iterable<DocInline> inlinesOf(List<DocBlock> blocks) sync* {
  for (final block in blocks) {
    switch (block) {
      case ParagraphBlock():
        yield* block.spans;
      case HeadingBlock():
        yield* block.spans;
      case ListBlock():
        for (final item in block.items) {
          yield* inlinesOf(item);
        }
      case QuoteBlock():
        yield* inlinesOf(block.children);
      case TheoremBlock():
        if (block.title != null) yield* block.title!;
        yield* inlinesOf(block.body);
      case BibliographyBlock():
        for (final entry in block.entries) {
          yield* entry.spans;
        }
      case TableBlock():
        for (final row in block.rows) {
          for (final cell in row) {
            yield* cell.spans;
          }
        }
      case CenterBlock():
        yield* inlinesOf(block.children);
      case FramedBlock():
        yield* inlinesOf(block.children);
      case CaptionBlock():
        yield* block.spans;
      case FootnoteBlock():
        yield* block.spans;
      case TikzDiagramBlock():
        for (final line in block.diagram.allLabelLines) {
          yield* parseInline(line);
        }
      case TitleBlock():
      case DisplayMathBlock():
      case CodeBlock():
      case DiagramBlock():
        break;
    }
  }
}

void main() {
  group('parseLatexDocument', () {
    test('splits prose and display math', () {
      final blocks = parseLatexDocument(r'''
Some text before.

$$ e = mc^2 $$

Text after \[ \sqrt{2} \] and beyond.
''');
      // Display math splits the surrounding prose, so "Text after ... and
      // beyond." contributes two paragraphs around its formula.
      expect(blocks, hasLength(5));
      expect(blocks[0], isA<ParagraphBlock>());
      expect((blocks[1] as DisplayMathBlock).latex, 'e = mc^2');
      expect(blocks[2], isA<ParagraphBlock>());
      expect((blocks[3] as DisplayMathBlock).latex, r'\sqrt{2}');
      final tail = blocks[4] as ParagraphBlock;
      expect((tail.spans.single as TextRun).text, contains('and beyond.'));
    });

    test('passes math environments through whole', () {
      final blocks = parseLatexDocument(r'''
\begin{align}
  a &= b \\
  c &= d
\end{align}
''');
      final math = blocks.single as DisplayMathBlock;
      expect(math.latex, startsWith(r'\begin{align}'));
      expect(math.latex, endsWith(r'\end{align}'));
    });

    test('rewrites display environments RaTeX does not lay out', () {
      const source = r'''
\begin{multline}
a + b \\
+ c
\end{multline}
\begin{eqnarray*}
x & = & \frac{1}{2} \\
y & \le & \begin{cases} 1 & z \end{cases}
\end{eqnarray*}
\begin{flalign}
p &= q
\end{flalign}
''';
      final maths = parseLatexDocument(
        source,
      ).whereType<DisplayMathBlock>().toList();
      expect(maths.map((m) => m.latex), [
        '\\begin{equation}\\begin{gathered}\na + b \\\\\n+ c\n'
            '\\end{gathered}\\end{equation}',
        '\\begin{align*}\nx & =  \\frac{1}{2} \\\\\n'
            'y & \\le  \\begin{cases} 1 & z \\end{cases}\n\\end{align*}',
        '\\begin{align}\np &= q\n\\end{align}',
      ]);
      for (final math in maths) {
        final map = math.latexSourceMap!;
        expect(map, hasLength(math.latex.length));
        // Copied text still maps to itself in the source.
        final body = math.latex.indexOf('\n') + 1;
        expect(source[map[body]], math.latex[body]);
      }
      final eqnarray = maths[1];
      final half = eqnarray.latex.indexOf(r'\frac');
      expect(
        source.substring(
          eqnarray.latexSourceMap![half],
          eqnarray.latexSourceMap![half] + 5,
        ),
        r'\frac',
      );
    });

    test('subequations adds nothing around its display math', () {
      final blocks = parseLatexDocument(
        '\\begin{subequations}\n\\begin{align}\na &= b\n\\end{align}\n'
        '\\end{subequations}',
      );
      expect(blocks.single, isA<DisplayMathBlock>());
      expect(
        inlinesOf(blocks).whereType<TextRun>().map((s) => s.text).join(),
        isEmpty,
      );
    });

    test('captures lstlisting as a verbatim CodeBlock', () {
      final blocks = parseLatexDocument(r'''
\begin{lstlisting}[language=Rust, caption=Demo]
fn main() { // 50% done
    println!("hi");
}
\end{lstlisting}
''');
      final code = blocks.whereType<CodeBlock>().single;
      expect(code.code, 'fn main() { // 50% done\n    println!("hi");\n}');
    });

    test('captures plain verbatim, preserving blank lines', () {
      final blocks = parseLatexDocument(r'''
\begin{verbatim}
first

third
\end{verbatim}
''');
      final code = blocks.whereType<CodeBlock>().single;
      expect(code.code, 'first\n\nthird');
    });

    test('does not mistake a leading `[` in code for lstlisting options', () {
      final blocks = parseLatexDocument(r'''
\begin{lstlisting}
[derive(Clone)]
struct Foo;
\end{lstlisting}
''');
      final code = blocks.whereType<CodeBlock>().single;
      expect(code.code, '[derive(Clone)]\nstruct Foo;');
    });

    test('captures quote as an indented QuoteBlock', () {
      final blocks = parseLatexDocument(r'''
\begin{quote}
\paragraph{Recommendation} Fix it.
\end{quote}
''');
      final quote = blocks.whereType<QuoteBlock>().single;
      final text = inlinesOf(
        quote.children,
      ).whereType<TextRun>().map((s) => s.text).join();
      expect(text, contains('Recommendation'));
      expect(text, contains('Fix it.'));
    });

    test('captures abstract as an Abstract heading plus a paragraph', () {
      final blocks = parseLatexDocument(r'''
\begin{document}
\begin{abstract}
This paper is about things.
\end{abstract}
\end{document}
''');
      final heading = blocks.whereType<HeadingBlock>().single;
      expect((heading.spans.single as TextRun).text, 'Abstract');
      final paragraph = blocks.whereType<ParagraphBlock>().single;
      expect(
        (paragraph.spans.single as TextRun).text,
        contains('This paper is about things.'),
      );
    });

    test(
      'captures a theorem-like environment, resolving its \\label number',
      () {
        final blocks = parseLatexDocument(r'''
\begin{document}
\begin{definition}[Random Oracle]\label{def:ro}
A function modeled as uniformly random.
\end{definition}
See \cref{def:ro}.
\end{document}
''');
        final theorem = blocks.whereType<TheoremBlock>().single;
        expect(theorem.noun, 'Definition');
        expect(theorem.number, '1');
        final title = theorem.title!
            .whereType<TextRun>()
            .map((s) => s.text)
            .join();
        expect(title, 'Random Oracle');
        final body = inlinesOf(
          theorem.body,
        ).whereType<TextRun>().map((s) => s.text).join();
        expect(body, contains('uniformly random'));

        final crefText = blocks
            .whereType<ParagraphBlock>()
            .last
            .spans
            .whereType<TextRun>()
            .map((s) => s.text)
            .join();
        expect(crefText, contains('definition 1'));
      },
    );

    test('an unlabeled theorem environment is still numbered', () {
      final blocks = parseLatexDocument(r'''
\begin{document}
\begin{lemma}
Unlabeled but still counted.
\end{lemma}
\end{document}
''');
      final theorem = blocks.whereType<TheoremBlock>().single;
      expect(theorem.noun, 'Lemma');
      expect(theorem.number, '1');
    });

    test(r'\newtheorem declarations drive nouns, sharing, and resets', () {
      final blocks = parseLatexDocument(r'''
\newtheorem{resul}{Result}[section]
\newtheorem{conj}[resul]{Conjecture}
\begin{document}
\section{One}
\begin{resul}first\end{resul}
\begin{conj}\label{res:shared}second, shared counter\end{conj}
\section{Two}
\begin{resul}reset by section\end{resul}
See \cref{res:shared}.
\end{document}
''');
      final theorems = blocks.whereType<TheoremBlock>().toList();
      expect(theorems.map((t) => t.noun), ['Result', 'Conjecture', 'Result']);
      expect(theorems.map((t) => t.number), ['1.1', '1.2', '2.1']);
      final crefText = inlinesOf([
        blocks.last,
      ]).whereType<TextRun>().map((s) => s.text).join();
      expect(crefText, contains('conjecture 1.2'));
    });

    test(r'\newtheorem* environments are unnumbered', () {
      final blocks = parseLatexDocument(r'''
\newtheorem*{remark}{Remark}
\newtheorem{claim}{Claim}
\begin{document}
\begin{remark}aside\end{remark}
\begin{claim}\label{cl:one}counted\end{claim}
\Cref{cl:one}
\end{document}
''');
      final theorems = blocks.whereType<TheoremBlock>().toList();
      expect(theorems.map((t) => t.noun), ['Remark', 'Claim']);
      expect(theorems.map((t) => t.number), [null, '1']);
      final refText = inlinesOf([
        blocks.last,
      ]).whereType<TextRun>().map((s) => s.text).join();
      expect(refText, contains('Claim 1'));
    });

    test('starred sections do not step the section counters', () {
      final blocks = parseLatexDocument(r'''
\newtheorem{claim}{Claim}[section]
\begin{document}
\section*{Introduction}
\section{First}\label{sec:first}
\begin{claim}in the first numbered section\end{claim}
\subsection*{Unnumbered}
\subsection{Numbered}\label{sec:sub}
\ref{sec:first} and \ref{sec:sub}
\end{document}
''');
      expect(blocks.whereType<HeadingBlock>(), hasLength(4));
      expect(blocks.whereType<TheoremBlock>().single.number, '1.1');
      final refText = inlinesOf([
        blocks.last,
      ]).whereType<TextRun>().map((s) => s.text).join();
      expect(refText, contains('1 and 1.1'));
    });

    test(r'\Cref of a theorem whose noun is blank does not throw', () {
      final blocks = parseLatexDocument(r'''
\newtheorem{foo}{ }
\begin{document}
\begin{foo}\label{x}body\end{foo}
\Cref{x}
\end{document}
''');
      final refText = inlinesOf([
        blocks.last,
      ]).whereType<TextRun>().map((s) => s.text).join();
      expect(refText, contains('1'));
    });

    test('an unlabeled theorem still shifts later numbers, like LaTeX', () {
      final blocks = parseLatexDocument(r'''
\begin{document}
\begin{definition}unlabeled\end{definition}
\begin{definition}\label{def:second}labeled\end{definition}
\ref{def:second}
\end{document}
''');
      final theorems = blocks.whereType<TheoremBlock>().toList();
      expect(theorems.map((t) => t.number), ['1', '2']);
      final refText = inlinesOf([
        blocks.last,
      ]).whereType<TextRun>().map((s) => s.text).join();
      expect(refText, contains('2'));
    });

    test('recognizes abbreviated theorem environment names', () {
      final blocks = parseLatexDocument(r'\begin{cor} A corollary. \end{cor}');
      expect(blocks.whereType<TheoremBlock>().single.noun, 'Corollary');
    });

    test(r'\begin{proof} is captured with noun "Proof"', () {
      final blocks = parseLatexDocument(r'''
\begin{proof}
Trivial.
\end{proof}
''');
      final proof = blocks.whereType<TheoremBlock>().single;
      expect(proof.noun, 'Proof');
      expect(proof.number, isNull);
      expect(
        inlinesOf(proof.body).whereType<TextRun>().map((s) => s.text).join(),
        contains('Trivial.'),
      );
    });

    test('extracts the document body and \\maketitle metadata', () {
      final blocks = parseLatexDocument(r'''
\documentclass{article}
\title{A Title}
\author{An Author}
\begin{document}
\maketitle
Body text.
\end{document}
Ignored trailer.
''');
      final title = blocks.whereType<TitleBlock>().single;
      expect(title.title, 'A Title');
      expect(title.author, 'An Author');
      expect(title.date, isNull);
      final paragraph = blocks.whereType<ParagraphBlock>().single;
      expect((paragraph.spans.single as TextRun).text, contains('Body text.'));
      expect(
        blocks.whereType<ParagraphBlock>().length,
        1,
        reason: 'content outside the document environment is dropped',
      );
    });

    test('maps formulas in title metadata back to the original source', () {
      const source =
          '\\title{A % ignored\r\nformula \$x+\\oops\$}\r\n'
          '\\begin{document}\\maketitle\\end{document}';

      final title = parseLatexDocument(source).whereType<TitleBlock>().single;
      final math = parseInline(
        title.title!,
        sourceMap: title.titleSourceMap,
      ).whereType<InlineMath>().single;

      final constructStart = source.indexOf(r'$x+\oops$');
      expect(math.sourceStart, constructStart);
      expect(math.sourceEnd, constructStart + r'$x+\oops$'.length);
    });

    test('title metadata expands the document macros like the body', () {
      final title = parseLatexDocument(r'''
\newcommand{\Product}{ManyMath}
\title{\Product{} Notes on $x$}
\author{The \Product{} team}
\begin{document}\maketitle\end{document}
''').whereType<TitleBlock>().single;
      String text(List<DocInline>? spans) =>
          spans!.whereType<TextRun>().map((s) => s.text).join();
      expect(text(title.titleInlines), 'ManyMath Notes on ');
      expect(title.titleInlines!.whereType<InlineMath>().single.latex, 'x');
      expect(text(title.authorInlines), 'The ManyMath team');
      expect(title.dateInlines, isNull);
      expect(title.metadataInlines, hasLength(2));
    });

    test('title metadata spans keep their source offsets', () {
      const source =
          '\\title{Plain \$y\$}\\begin{document}\\maketitle\\end{document}';
      final title = parseLatexDocument(source).whereType<TitleBlock>().single;
      final math = title.titleInlines!.whereType<InlineMath>().single;
      expect(math.sourceStart, source.indexOf(r'$y$'));
    });

    test('FROSTLASS paper lists all six authors', () {
      final title = parseLatexDocument(
        frostlassThresholdizationSource,
      ).whereType<TitleBlock>().single;
      for (final name in <String>[
        'Joshua Babb',
        'Brandon Goodell',
        'Luke Parker',
        'Rigo Salazar',
        'Freeman Slaughter',
        'Luke Szramowski',
      ]) {
        expect(title.author, contains(name));
      }
    });

    test('a short title option keeps the full heading and its number', () {
      final blocks = parseLatexDocument(r'''
\begin{document}
\section[subtle]{A subtle long title}\label{sec:a}
\subsection [Short] {Second level}
See \ref{sec:a}.
\end{document}
''');
      final headings = blocks.whereType<HeadingBlock>().toList();
      expect(headings.map((h) => h.level), [1, 2]);
      expect(
        headings.map(
          (h) => h.spans.whereType<TextRun>().map((s) => s.text).join(),
        ),
        ['A subtle long title', 'Second level'],
      );
      final refText = inlinesOf([
        blocks.last,
      ]).whereType<TextRun>().map((s) => s.text).join();
      expect(refText, contains('See 1.'));
    });

    test('parses sections with levels', () {
      final blocks = parseLatexDocument(
        '\\section{One}\n\\subsection{Two}\n\\subsubsection{Three}',
      );
      final headings = blocks.whereType<HeadingBlock>().toList();
      expect(headings.map((h) => h.level), [1, 2, 3]);
      expect((headings[0].spans.single as TextRun).text, 'One');
    });

    test('parses itemize and enumerate', () {
      final blocks = parseLatexDocument(r'''
\begin{itemize}
  \item First with $x^2$ math
  \item Second
\end{itemize}
\begin{enumerate}
  \item Numbered
\end{enumerate}
''');
      final bullets = blocks[0] as ListBlock;
      expect(bullets.style, ListStyle.bullet);
      expect(bullets.items, hasLength(2));
      expect(
        inlinesOf(bullets.items[0]).whereType<InlineMath>().single.latex,
        'x^2',
      );
      final numbered = blocks[1] as ListBlock;
      expect(numbered.style, ListStyle.numbered);
    });

    test('parses description, keeping the required label bolded', () {
      final blocks = parseLatexDocument(r'''
\begin{description}
  \item[Source] file.rs:10
  \item[Spec] Does the thing
\end{description}
''');
      final list = blocks.single as ListBlock;
      expect(list.style, ListStyle.description);
      expect(list.items, hasLength(2));
      final first = inlinesOf(list.items[0]).toList();
      final label = first.first as TextRun;
      expect(label.text, 'Source');
      expect(label.bold, isTrue);
      final text = first.map((s) => (s as TextRun).text).join();
      expect(text, contains('file.rs:10'));
    });

    test('expands the paper\'s own prose macros', () {
      final blocks = parseLatexDocument(r'''
\newcommand{\src}[1]{\texttt{#1}}
\begin{document}
See \src{crypto-ops.c} for details.
\end{document}
''');
      final paragraph = blocks.single as ParagraphBlock;
      final code = paragraph.spans.whereType<TextRun>().firstWhere(
        (s) => s.text == 'crypto-ops.c',
      );
      expect(code.monospace, isTrue);
    });

    test('macro-heavy content never throws and reads as plain prose', () {
      final blocks = parseLatexDocument(r'''
\newcommand{\ghlink}[2]{\href{#1}{#2}}
\newcommand{\prlink}[2]{PR \##1: #2}
\begin{document}
\ghlink{https://x}{fe\_batch\_invert} was touched in \prlink{10111}{Batch inverse}.
\end{document}
''');
      final paragraph = blocks.single as ParagraphBlock;
      final text = paragraph.spans
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(text, contains('fe_batch_invert'));
      expect(text, contains('PR #10111: Batch inverse'));
      expect(text, isNot(contains(r'\ghlink')));
      expect(text, isNot(contains('https://x')));
    });

    test('a macro cycle does not loop forever', () {
      final blocks = parseLatexDocument(r'''
\newcommand{\a}{\b}
\newcommand{\b}{\a}
\begin{document}
Value: \a done.
\end{document}
''');
      final paragraph = blocks.single as ParagraphBlock;
      expect(
        paragraph.spans.whereType<TextRun>().map((s) => s.text).join(),
        contains('done.'),
      );
    });

    test(
      'a control word does not swallow a following expansion (\\to + b)',
      () {
        // Regression: \verifyO expands to the bare letter "b"; naively
        // concatenating it right after the real (unexpanded) \to would
        // read back as the single undefined control word \tob.
        final blocks = parseLatexDocument(r'''
\newcommand{\verifyO}{b}
\newcommand{\verifyIO}{\to\verifyO}
\begin{document}
Outputs \verifyIO here.
\end{document}
''');
        final text = (blocks.single as ParagraphBlock).spans
            .whereType<TextRun>()
            .map((s) => s.text)
            .join();
        expect(text, isNot(contains(r'\tob')));
      },
    );

    test('strips comments but keeps escaped percent signs', () {
      final blocks = parseLatexDocument(
        'Visible % gone\nStill visible: 50\\% of it.',
      );
      final paragraph = blocks.single as ParagraphBlock;
      final text = paragraph.spans
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(text, isNot(contains('gone')));
      expect(text, contains('50% of it'));
    });

    test('a %-joined line drops its indentation, as TeX does', () {
      const source = 'foo%\n    bar and x%\n\t  \$y\$';
      final paragraph = parseLatexDocument(source).single as ParagraphBlock;
      final text = paragraph.spans
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(text, 'foobar and x');
      expect(
        paragraph.spans.whereType<InlineMath>().single.sourceStart,
        source.indexOf(r'$y$'),
      );
    });

    test('a commented-out verbatim begin does not disable comments', () {
      final blocks = parseLatexDocument(
        '% \\begin{lstlisting}\nvisible % hidden\n% whole line\nmore',
      );
      final text = inlinesOf(
        blocks,
      ).whereType<TextRun>().map((span) => span.text).join();
      expect(text, contains('visible'));
      expect(text, contains('more'));
      expect(text, isNot(contains('hidden')));
      expect(text, isNot(contains('whole line')));
    });

    test('a one-line verbatim environment does not disable comments', () {
      final blocks = parseLatexDocument(
        '\\begin{verbatim}x % kept\\end{verbatim}\nafter % gone',
      );
      final text = inlinesOf(
        blocks,
      ).whereType<TextRun>().map((span) => span.text).join();
      expect(text, contains('after'));
      expect(text, isNot(contains('gone')));
    });

    test(r'a percent sign inside \verb is not a comment', () {
      final blocks = parseLatexDocument(r'use \verb|50%| here and more');
      final text = inlinesOf(
        blocks,
      ).whereType<TextRun>().map((span) => span.text).join();
      expect(text, contains('here and more'));
    });

    test('an inline comment consumes its newline', () {
      final blocks = parseLatexDocument(
        'joined% no whitespace survives\n'
        'word and \$\\frac% formula continues\n'
        '{1}{2}\$',
      );
      final paragraph = blocks.single as ParagraphBlock;
      final text = paragraph.spans
          .whereType<TextRun>()
          .map((span) => span.text)
          .join();
      expect(text, startsWith('joinedword'));
      expect(
        paragraph.spans.whereType<InlineMath>().single.latex,
        r'\frac{1}{2}',
      );
    });

    // Regression tests for review findings (each was a reproduced bug).

    test(r'\end{document} before \begin{document} does not crash', () {
      final blocks = parseLatexDocument(r'\end{document}\begin{document}hello');
      final paragraph = blocks.whereType<ParagraphBlock>().single;
      expect((paragraph.spans.single as TextRun).text, 'hello');
    });

    test(r'\\[2pt] line breaks do not open display math', () {
      final blocks = parseLatexDocument(
        'Line one \\\\[2pt]\nLine two\n\n\\[ x^2 \\]',
      );
      expect(blocks.whereType<DisplayMathBlock>().single.latex, 'x^2');
      final text = blocks
          .whereType<ParagraphBlock>()
          .expand((p) => p.spans)
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(text, contains('Line two'));
      expect(text, isNot(contains('2pt')));
    });

    test(r'escaped \$ does not open $$ display math', () {
      final blocks = parseLatexDocument(
        'It costs \\\$\$x\$ dollars.\n\n\$\$ y = 2 \$\$',
      );
      expect(blocks.whereType<DisplayMathBlock>().single.latex, 'y = 2');
      final first = blocks.first as ParagraphBlock;
      expect(first.spans.whereType<InlineMath>().single.latex, 'x');
      final text = first.spans.whereType<TextRun>().map((s) => s.text).join();
      expect(text, contains(r'$'));
      expect(text, contains('dollars.'));
    });

    test('a comment-only line does not split the paragraph', () {
      final blocks = parseLatexDocument(
        'first half of sentence\n% a comment line\nsecond half',
      );
      expect(blocks.whereType<ParagraphBlock>(), hasLength(1));
    });

    test(r'\\% is a comment, not an escaped percent', () {
      final blocks = parseLatexDocument('break \\\\% gone\nnext');
      final text = blocks
          .whereType<ParagraphBlock>()
          .expand((p) => p.spans)
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(text, isNot(contains('gone')));
      expect(text, contains('next'));
    });

    test('nested itemize becomes a real nested ListBlock', () {
      final blocks = parseLatexDocument(
        r'\begin{itemize}\item outer'
        r'\begin{itemize}\item inner\end{itemize}'
        r'\item outer2\end{itemize}',
      );
      final list = blocks.whereType<ListBlock>().single;
      expect(list.items, hasLength(2), reason: 'inner \\item is not ours');
      final inner = list.items[0].whereType<ListBlock>().single;
      expect(
        inlinesOf(
          inner.items.single,
        ).whereType<TextRun>().map((s) => s.text).join(),
        contains('inner'),
      );
      final outer2 = inlinesOf(
        list.items[1],
      ).whereType<TextRun>().map((s) => s.text).join();
      expect(outer2, contains('outer2'));
      expect(
        blocks.whereType<ParagraphBlock>(),
        isEmpty,
        reason: 'nothing may leak out of the list',
      );
    });

    test(r'\itemsep is not an item boundary', () {
      final blocks = parseLatexDocument(
        '\\begin{itemize}\\itemsep0pt\n\\item only one\\end{itemize}',
      );
      final list = blocks.whereType<ListBlock>().single;
      // The \itemsep prefix survives as (degraded) text, but must not
      // create a bogus extra bullet beyond it.
      final bulletsWithContent = list.items
          .where(
            (item) => inlinesOf(
              item,
            ).whereType<TextRun>().any((s) => s.text.contains('only one')),
          )
          .toList();
      expect(bulletsWithContent, hasLength(1));
    });

    test('display math inside a list item is real display math', () {
      final blocks = parseLatexDocument(
        r'\begin{itemize}\item The identity $$e^{i\pi} = -1$$ holds'
        r'\end{itemize}',
      );
      final item = blocks.whereType<ListBlock>().single.items.single;
      expect(item.whereType<DisplayMathBlock>().single.latex, r'e^{i\pi} = -1');
      final text = inlinesOf(
        item,
      ).whereType<TextRun>().map((s) => s.text).join();
      expect(text, isNot(contains(r'$')));
    });

    test(r'adjacent inline maths $a$$b$ are not display math', () {
      final blocks = parseLatexDocument(
        'sum of \$a\$\$b\$ terms\n\n\$\$ x \$\$',
      );
      expect(blocks.whereType<DisplayMathBlock>().single.latex, 'x');
      final first = blocks.first as ParagraphBlock;
      expect(first.spans.whereType<InlineMath>().map((m) => m.latex), [
        'a',
        'b',
      ]);
    });

    test('content before the first \\item is not a bullet', () {
      final blocks = parseLatexDocument(
        '\\begin{itemize}\\itemsep0pt\n\\item real\\end{itemize}',
      );
      final list = blocks.whereType<ListBlock>().single;
      expect(list.items, hasLength(1));
      expect((inlinesOf(list.items.single).single as TextRun).text, 'real');
    });

    test(r'\item[label] optional arguments are stripped', () {
      final blocks = parseLatexDocument(
        r'\begin{itemize}\item[(a)] first\item second\end{itemize}',
      );
      final list = blocks.whereType<ListBlock>().single;
      expect((inlinesOf(list.items[0]).single as TextRun).text, 'first');
      expect((inlinesOf(list.items[1]).single as TextRun).text, 'second');
    });

    test(r'\[..\] inside a list item is real display math', () {
      final blocks = parseLatexDocument(
        r'\begin{itemize}\item yields \[ \zeta(2) \] here\end{itemize}',
      );
      final item = blocks.whereType<ListBlock>().single.items.single;
      expect(item.whereType<DisplayMathBlock>().single.latex, r'\zeta(2)');
    });

    test(r'\thanks is dropped and \today renders a real date', () {
      final spans = parseInline(r'Joshua Babb\thanks{Cypher Stack}, \today.');
      final text = spans.whereType<TextRun>().map((s) => s.text).join();
      expect(text, isNot(contains(r'\thanks')));
      expect(text, isNot(contains('Cypher Stack')));
      expect(text, isNot(contains(r'\today')));
      expect(text, contains(RegExp(r'Joshua Babb, [A-Z][a-z]+ \d+, \d{4}\.')));
    });

    test('TeX dash and quote ligatures render, except in monospace', () {
      final spans = parseInline("pages 3--5 --- ``quoted'' \\texttt{fe--x}");
      final text = spans.whereType<TextRun>().map((s) => s.text).join();
      expect(text, contains('3–5'));
      expect(text, contains('—'));
      expect(text, contains('“quoted”'));
      expect(text, contains('fe--x'), reason: 'tt fonts keep literal dashes');
    });

    test(r'\title {X} with whitespace before the brace still parses', () {
      final blocks = parseLatexDocument(
        '\\title {Spaced}\n\\begin{document}\\maketitle\\end{document}',
      );
      expect(blocks.whereType<TitleBlock>().single.title, 'Spaced');
    });

    test('CRLF documents still get paragraph breaks', () {
      final blocks = parseLatexDocument(
        'para one\r\n\r\npara two\r\n\r\npara three',
      );
      expect(blocks.whereType<ParagraphBlock>(), hasLength(3));
    });

    test('never throws on malformed input', () {
      for (final source in [
        r'\begin{align} unterminated',
        r'$$ unterminated',
        r'\section{unclosed',
        r'\[',
        '',
        r'\end{document}',
      ]) {
        expect(
          () => parseLatexDocument(source),
          returnsNormally,
          reason: source,
        );
      }
    });
  });

  group('source spans', () {
    test('inline math maps normalized content to exact source offsets', () {
      const source = 'before % removed\r\nthen \$  x\r\n+y  \$ after';
      final math = parseLatexDocument(source)
          .whereType<ParagraphBlock>()
          .expand((p) => p.spans)
          .whereType<InlineMath>()
          .single;
      final x = source.indexOf('x');

      expect(math.latex, 'x\n+y');
      expect(math.latexSourceMap, [x, x + 1, x + 3, x + 4]);
      expect(math.sourceStart, source.indexOf(r'$'));
      expect(math.sourceEnd, source.lastIndexOf(r'$') + 1);
    });

    test('display math maps normalized content to exact source offsets', () {
      const source = 'before % removed\r\n\$\$  a\r\n+b  \$\$ after';
      final math = parseLatexDocument(
        source,
      ).whereType<DisplayMathBlock>().single;
      final a = source.indexOf('a', source.indexOf(r'$$'));

      expect(math.latex, 'a\n+b');
      expect(math.latexSourceMap, [a, a + 1, a + 3, a + 4]);
      expect(math.sourceStart, source.indexOf(r'$$'));
      expect(math.sourceEnd, source.lastIndexOf(r'$$') + 2);
    });

    test(r'display math $$..$$ spans the whole construct', () {
      const source = 'Some text.\n\n\$\$ e = mc^2 \$\$\ntail';
      final math = parseLatexDocument(
        source,
      ).whereType<DisplayMathBlock>().single;
      final start = source.indexOf(r'$$');
      final end = source.indexOf(r'$$', start + 2) + 2;
      expect(math.latex, 'e = mc^2');
      expect(math.sourceStart, start);
      expect(math.sourceEnd, end);
      expect(
        source.substring(math.sourceStart!, math.sourceEnd!),
        r'$$ e = mc^2 $$',
      );
    });

    test('inline math spans survive a stripped comment on an earlier line', () {
      const source = 'pre % note\nmid \$a+b\$ end';
      final math = parseLatexDocument(source)
          .whereType<ParagraphBlock>()
          .expand((p) => p.spans)
          .whereType<InlineMath>()
          .single;
      final start = source.indexOf(r'$a+b$');
      expect(math.sourceStart, start);
      expect(math.sourceEnd, start + r'$a+b$'.length);
    });

    test('spans survive CRLF normalization', () {
      const source = 'para\r\n\r\n\$\$x\$\$\r\nafter';
      final math = parseLatexDocument(
        source,
      ).whereType<DisplayMathBlock>().single;
      final start = source.indexOf(r'$$x$$');
      expect(math.sourceStart, start);
      expect(math.sourceEnd, start + r'$$x$$'.length);
    });

    test('math environments span \\begin through \\end', () {
      const source = '\\begin{align}\r\n  a &= b\r\n\\end{align}';
      final math = parseLatexDocument(
        source,
      ).whereType<DisplayMathBlock>().single;
      expect(math.sourceStart, 0);
      expect(math.sourceEnd, source.length);
    });

    test('inline math inside list items carries spans', () {
      const source =
          '\\begin{itemize}\n  \\item has \$x^2\$ inside\n'
          '\\end{itemize}';
      final math = inlinesOf(
        parseLatexDocument(source).whereType<ListBlock>().single.items.single,
      ).whereType<InlineMath>().single;
      final start = source.indexOf(r'$x^2$');
      expect(math.sourceStart, start);
      expect(math.sourceEnd, start + r'$x^2$'.length);
    });

    test('inline math in headings carries spans', () {
      const source = r'\section{About $\pi$}';
      final math = parseLatexDocument(
        source,
      ).whereType<HeadingBlock>().single.spans.whereType<InlineMath>().single;
      final start = source.indexOf(r'$\pi$');
      expect(math.sourceStart, start);
      expect(math.sourceEnd, start + r'$\pi$'.length);
    });

    test('spans survive the document-body slice', () {
      const source =
          '\\title{T}\n\\begin{document}\nx \$y\$ z\n\\end{document}';
      final math = parseLatexDocument(source)
          .whereType<ParagraphBlock>()
          .expand((p) => p.spans)
          .whereType<InlineMath>()
          .single;
      final start = source.indexOf(r'$y$');
      expect(math.sourceStart, start);
      expect(math.sourceEnd, start + r'$y$'.length);
    });

    test('math nested in styles carries spans', () {
      const source = r'\textbf{bold $k$} rest';
      final math = parseLatexDocument(source)
          .whereType<ParagraphBlock>()
          .expand((p) => p.spans)
          .whereType<InlineMath>()
          .single;
      final start = source.indexOf(r'$k$');
      expect(math.sourceStart, start);
      expect(math.sourceEnd, start + r'$k$'.length);
    });

    test('comment-only lines before math do not shift spans', () {
      const source = '% c1\n% c2\n\$\$z\$\$';
      final math = parseLatexDocument(
        source,
      ).whereType<DisplayMathBlock>().single;
      final start = source.indexOf(r'$$z$$');
      expect(math.sourceStart, start);
      expect(math.sourceEnd, start + r'$$z$$'.length);
    });

    test(r'\( \) constructs carry spans', () {
      const source = r'a \(u\) b';
      final math = parseLatexDocument(source)
          .whereType<ParagraphBlock>()
          .expand((p) => p.spans)
          .whereType<InlineMath>()
          .single;
      expect(math.sourceStart, source.indexOf(r'\('));
      expect(math.sourceEnd, source.indexOf(r'\)') + 2);
    });

    test('inline math beside references keeps exact spans', () {
      const source = r'''
\begin{document}
\section{A}\label{sec:a}
By \cite{k} and \ref{sec:a}\label{x}, $y^2$ holds; \cref{sec:a} too.
\begin{thebibliography}{9}
\bibitem{k} Someone. 2020.
\end{thebibliography}
\end{document}
''';
      final paragraph = parseLatexDocument(
        source,
      ).whereType<ParagraphBlock>().first;
      final math = paragraph.spans.whereType<InlineMath>().single;
      expect(math.sourceStart, source.indexOf(r'$y^2$'));
      expect(math.sourceEnd, source.indexOf(r'$y^2$') + r'$y^2$'.length);
    });

    test('parseInline without a sourceMap yields null spans', () {
      final math = parseInline(r'has $x$').whereType<InlineMath>().single;
      expect(math.sourceStart, isNull);
      expect(math.sourceEnd, isNull);
    });
  });

  group('countDocument', () {
    test('counts words and formulas across block kinds', () {
      final blocks = parseLatexDocument(r'''
\title{Two Words}
\begin{document}
\maketitle
\section{One $a$}

Three plain words here $x$ and $$y$$

\begin{itemize}
  \item two words $z$
\end{itemize}
\end{document}
''');
      final counts = countDocument(blocks);
      // Words: "Two Words" (2) + "One" (1) + "Three plain words here"
      // + "and" (5) + "two words" (2) = 10.
      expect(counts.words, 10);
      // Formulas: $a$, $x$, $$y$$, $z$ = 4.
      expect(counts.formulas, 4);
    });
  });

  group('parseInline', () {
    test('mixes text, math, and styles', () {
      final spans = parseInline(
        r'Let $x$ be \textbf{bold and \emph{nested}} fine.',
      );
      expect(spans.whereType<InlineMath>().single.latex, 'x');
      final bold = spans.whereType<TextRun>().firstWhere(
        (s) => s.text.contains('bold'),
      );
      expect(bold.bold, isTrue);
      expect(bold.italic, isFalse);
      final nested = spans.whereType<TextRun>().firstWhere(
        (s) => s.text.contains('nested'),
      );
      expect(nested.bold, isTrue);
      expect(nested.italic, isTrue);
    });

    test('face and family switches keep their text', () {
      final spans = parseInline(
        r'A \textsc{Nist} and \mbox{y z} in \textrm{roman} \textsf{sans}.',
      );
      final text = spans.whereType<TextRun>().map((s) => s.text).join();
      expect(text, 'A Nist and y z in roman sans.');
    });

    test(r'\bibliography is dropped like \bibliographystyle', () {
      final spans = parseInline(
        r'Text. \bibliographystyle{plain}\bibliography{refs}',
      );
      final text = spans.whereType<TextRun>().map((s) => s.text).join();
      expect(text.trim(), 'Text.');
    });

    test(
      'a command without arguments does not swallow a following bracket',
      () {
        final spans = parseInline(r'\noindent [0,1] is an interval');
        final text = spans.whereType<TextRun>().map((s) => s.text).join();
        expect(text.trim(), '[0,1] is an interval');
      },
    );

    test('an accent over an astral character keeps the pair whole', () {
      final spans = parseInline("\\'{\u{1D44E}}x");
      final text = spans.whereType<TextRun>().map((s) => s.text).join();
      expect(text, '\u{1D44E}\u0301x');
    });

    test(r'handles \( \) inline math and line breaks', () {
      final spans = parseInline(r'Before \(a+b\) after \\ next line');
      expect(spans.whereType<InlineMath>().single.latex, 'a+b');
      expect(spans.whereType<TextRun>().any((s) => s.text == '\n'), isTrue);
    });

    test(r'escaped \$ stays text', () {
      final spans = parseInline(r'Costs \$5 plus \$6.');
      expect(spans.whereType<InlineMath>(), isEmpty);
      expect((spans.single as TextRun).text, r'Costs $5 plus $6.');
    });

    test(r'\paragraph and \subparagraph are bold run-in headings', () {
      final spans = parseInline(r'\paragraph{Problem} Something is wrong.');
      expect(spans, hasLength(2));
      final heading = spans.first as TextRun;
      expect(heading.text, 'Problem');
      expect(heading.bold, isTrue);
      final body = spans.last as TextRun;
      expect(body.text, contains('Something is wrong.'));
      expect(body.bold, isFalse);
    });

    test(r'\texttt and \underline are styled text', () {
      final tt = parseInline(r'\texttt{carrot_core}').single as TextRun;
      expect(tt.text, 'carrot_core');
      expect(tt.monospace, isTrue);

      final ul = parseInline(r'\underline{sk}').single as TextRun;
      expect(ul.text, 'sk');
      expect(ul.underline, isTrue);
    });

    test(r'\gls shows its term unstyled', () {
      final run = parseInline(r'\gls{monero-generators}').single as TextRun;
      expect(run.text, 'monero-generators');
      expect(run.bold, isFalse);
      expect(run.monospace, isFalse);
    });

    test(r'\path is shown verbatim, like \url', () {
      final run =
          parseInline(r'\path{/serai/networks/monero/}').single as TextRun;
      expect(run.text, '/serai/networks/monero/');
      expect(run.monospace, isTrue);
    });

    test(r'\ldots/\dots become an ellipsis, \textdagger a dagger', () {
      expect(
        (parseInline(r'a\ldots b\dots c\textdagger').single as TextRun).text,
        'a… b… c†',
      );
    });

    test(r'\protect is a no-op, \hfill and \vspace produce nothing', () {
      final spans = parseInline(r'a\protect\ref{x} b\hfill c\vspace{2pt} d');
      final text = spans.whereType<TextRun>().map((s) => s.text).join();
      expect(text, contains('a?? b c d'));
      expect(text, isNot(contains('protect')));
      expect(text, isNot(contains('hfill')));
      expect(text, isNot(contains('vspace')));
    });

    test(r'\textsuperscript shows its content unstyled', () {
      final run = parseInline(r'\textsuperscript{1}').single as TextRun;
      expect(run.text, '1');
    });

    test('TeX accent commands become a base letter plus a combining mark', () {
      // The base letter followed by a Unicode combining mark (\u0308 etc.),
      // not a precomposed character -- visually identical once shaped, but
      // spelled out with escapes here so the assertion is exact.
      const diaeresis = '\u0308';
      const acute = '\u0301';
      const cedilla = '\u0327';
      // Bare form (\"u) and braced form (\"{u}) both accent just the "u".
      expect(
        (parseInline(r'B\"unz').single as TextRun).text,
        'Bu${diaeresis}nz',
      );
      expect(
        (parseInline(r'B\"{u}nz').single as TextRun).text,
        'Bu${diaeresis}nz',
      );
      // Acute, and a letter-named accent (cedilla), which requires braces.
      expect((parseInline(r"S\'aez").single as TextRun).text, 'Sa${acute}ez');
      expect(
        (parseInline(r'Fran\c{c}ois').single as TextRun).text,
        'Franc${cedilla}ois',
      );
    });

    test(r'a nested command inside an accent argument is left alone', () {
      // \"{\i} is LaTeX's dotless-i idiom; guessing at it would be wrong
      // more often than not, so it's left as literal source instead.
      final text = parseInline(r'\"{\i}').single as TextRun;
      expect(text.text, r'\"{\i}');
    });

    test(r'\href shows only its second argument', () {
      final spans = parseInline(r'See \href{https://example.com}{the docs}.');
      final text = spans.whereType<TextRun>().map((s) => s.text).join();
      expect(text, 'See the docs.');
      expect(text, isNot(contains('example.com')));
    });

    test(r'\url is shown verbatim, unescaped, as monospace text', () {
      final run = parseInline(r'\url{https://x.com/a_b%20c}').single as TextRun;
      expect(run.text, r'https://x.com/a_b%20c');
      expect(run.monospace, isTrue);
    });

    test(r'\textcolor shows only its second argument', () {
      final spans = parseInline(r'\textcolor{red}{danger}');
      final text = spans.whereType<TextRun>().map((s) => s.text).join();
      expect(text, 'danger');
    });
  });

  group('extractMacroPreamble', () {
    test('normalizes \\newcommand and \\renewcommand to \\providecommand', () {
      final preamble = extractMacroPreamble(r'''
\newcommand{\Fq}{\mathbb{F}_q}
\renewcommand{\epsilon}{\varepsilon}
''');
      expect(preamble, r'''
\providecommand{\Fq}{\mathbb{F}_q}
\providecommand{\epsilon}{\varepsilon}
''');
    });

    test('defines \\DeclareMathOperator macros as operator names', () {
      final preamble = extractMacroPreamble(r'''
\newcommand{\Fq}{\mathbb{F}_q}
\DeclareMathOperator{\negl}{negl}
\DeclareMathOperator*{\argmax}{arg\,max}
\DeclareMathOperator \Tr {Tr}
''');
      expect(preamble, r'''
\providecommand{\Fq}{\mathbb{F}_q}
\providecommand{\negl}{\operatorname{negl}}
\providecommand{\argmax}{\operatorname*{arg\,max}}
\providecommand{\Tr}{\operatorname{Tr}}
''');
    });

    test('keeps \\def as-is, including its parameter text', () {
      final preamble = extractMacroPreamble(r'\def\foo#1#2{#1 + #2}');
      expect(
        preamble,
        r'\def\foo#1#2{#1 + #2}'
        '\n',
      );
    });

    test('preserves an optional-argument count and default', () {
      final preamble = extractMacroPreamble(
        r'\newcommand{\ip}[2]{\langle #1, #2 \rangle}',
      );
      expect(
        preamble,
        r'\providecommand{\ip}[2]{\langle #1, #2 \rangle}'
        '\n',
      );
    });

    test('ignores commented-out declarations', () {
      final preamble = extractMacroPreamble(
        '% \\newcommand{\\hidden}{nope}\n\\newcommand{\\visible}{yes}',
      );
      expect(preamble, contains(r'\visible'));
      expect(preamble, isNot(contains('hidden')));
    });

    test('ignores invocations of unrelated commands', () {
      // \docsvlist is a call, not a declaration; only \do's own \def should
      // be picked up.
      final preamble = extractMacroPreamble(
        r'\def\do#1{\csdef{#1}{\mathbb{#1}}}'
        '\n'
        r'\docsvlist{N,Z,Q}',
      );
      expect(
        preamble,
        r'\def\do#1{\csdef{#1}{\mathbb{#1}}}'
        '\n',
      );
    });

    test('keeps unbraced macro names, e.g. \\newcommand\\foo{...}', () {
      final preamble = extractMacroPreamble(r'\newcommand\foo{bar}');
      expect(
        preamble,
        r'\providecommand\foo{bar}'
        '\n',
      );
    });

    test('returns an empty string when there are no declarations', () {
      expect(extractMacroPreamble(r'\section{Intro} $x^2$'), isEmpty);
    });
  });

  group('references (\\label/\\ref/\\cref/\\cite)', () {
    test(r'\ref/\cref resolve real section numbers', () {
      final blocks = parseLatexDocument(r'''
\begin{document}
\section{Alpha}
\subsection{Beta}\label{sec:beta}
See \ref{sec:beta} and \cref{sec:beta} and \Cref{sec:beta}.
\end{document}
''');
      final text = blocks
          .whereType<ParagraphBlock>()
          .last
          .spans
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(text, contains('See 1.1 and section 1.1 and Section 1.1.'));
    });

    test(r'\cref lists, \autoref, \pageref and cite notes', () {
      final blocks = parseLatexDocument(r'''
\begin{document}
\section{Alpha}\label{sec:a}
\begin{theorem}\label{thm:one}One.\end{theorem}
\begin{theorem}\label{thm:two}Two.\end{theorem}
\begin{lemma}\label{lem:three}Three.\end{lemma}
By \cref{thm:one,thm:two}, \Cref{thm:one,lem:three}, \autoref{sec:a} and
\cref{thm:one,missing}; see page \pageref{thm:one} and \cite[p.~3]{k},
\citep[see][Thm.~2]{k}, \citet{k}.
\begin{thebibliography}{9}
\bibitem{k} Someone. Something. 2020.
\end{thebibliography}
\end{document}
''');
      final text = blocks
          .whereType<ParagraphBlock>()
          .map((p) => p.spans.whereType<TextRun>().map((s) => s.text).join())
          .join(' ');
      expect(text, contains('theorems 1 and 2'));
      expect(text, contains('Theorem 1 and Lemma 1'));
      expect(text, contains('Section 1 and'));
      expect(text, contains('theorem 1 and ??'));
      expect(text, contains('see page ??'));
      expect(text, contains('[1, p. 3]'));
      expect(text, contains('[see 1, Thm. 2]'));
      expect(text, contains('[1].'));
      expect(text, isNot(contains(r'\')));
    });

    test(r'an unresolved \ref renders as ??, matching LaTeX', () {
      final blocks = parseLatexDocument(r'''
\begin{document}
See \ref{sec:missing}.
\end{document}
''');
      final text = (blocks.single as ParagraphBlock).spans
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(text, contains('See ??.'));
    });

    test(r'\label produces no visible text', () {
      final blocks = parseLatexDocument(r'''
\begin{document}
Some text\label{sec:x} continues here.
\end{document}
''');
      final text = (blocks.single as ParagraphBlock).spans
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(text, isNot(contains('label')));
      expect(text, contains('Some text'));
      expect(text, contains('continues here.'));
    });

    test('labels outside sec:/eq: are grouped by their own prefix', () {
      final blocks = parseLatexDocument(r'''
\begin{document}
\begin{definition}\label{def:first}First.\end{definition}
\begin{definition}\label{def:second}Second.\end{definition}
See \cref{def:first} and \cref{def:second}.
\end{document}
''');
      final text = blocks
          .whereType<ParagraphBlock>()
          .last
          .spans
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(text, contains('definition 1'));
      expect(text, contains('definition 2'));
    });

    test(r'\cite resolves against \bibitem numbers inside thebibliography', () {
      final blocks = parseLatexDocument(r'''
\begin{document}
As shown by \cite{shamir1979share,shoup2000practical}.

\begin{thebibliography}{9}
\bibitem{shamir1979share} Adi Shamir. How to share a secret. 1979.
\bibitem{shoup2000practical} Victor Shoup. Practical threshold signatures. 2000.
\end{thebibliography}
\end{document}
''');
      final citing = blocks
          .whereType<ParagraphBlock>()
          .first
          .spans
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(citing, contains('[1, 2]'));

      final bib = blocks.whereType<BibliographyBlock>().single;
      expect(bib.entries, hasLength(2));
      expect(bib.entries[0].number, 1);
      expect(bib.entries[1].number, 2);
      final firstText = bib.entries[0].spans
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(firstText, contains('Adi Shamir'));
    });

    test(r'an undefined \cite key renders as [?]', () {
      final blocks = parseLatexDocument(r'''
\begin{document}
See \cite{nonexistent}.
\begin{thebibliography}{9}
\bibitem{known} Someone. Something. 2020.
\end{thebibliography}
\end{document}
''');
      final text = blocks
          .whereType<ParagraphBlock>()
          .first
          .spans
          .whereType<TextRun>()
          .map((s) => s.text)
          .join();
      expect(text, contains('[?]'));
    });
  });

  group('Distributed Proofreaders / Project Gutenberg conventions', () {
    test(
      r'\DPtypo, \DPchg, \DPmod, \DPnote, \Pagelabel, \First, \Inum normalize in prose and preserve formula source maps',
      () {
        const source =
            r'\First{W}e have \DPtypo{teh}{the} \DPchg{old}{new} '
            r'\DPmod{v1}{v2}\DPnote{check scan}\Pagelabel{p42}'
            r'\DPPageSep{042.png}{42} item \Inum{1.} with $x^2 + 1$ here.';
        final blocks = parseLatexDocument(source);
        final para = blocks.single as ParagraphBlock;
        final text = para.spans.whereType<TextRun>().map((s) => s.text).join();
        expect(text, 'We have the new v2 item 1. with  here.');
        expect(text, isNot(contains('DP')));
        expect(text, isNot(contains('teh')));
        expect(text, isNot(contains('p42')));

        final math = para.spans.whereType<InlineMath>().single;
        expect(math.latex, 'x^2 + 1');
        expect(math.sourceStart, source.indexOf(r'$x^2 + 1$'));
        expect(
          math.sourceEnd,
          source.indexOf(r'$x^2 + 1$') + r'$x^2 + 1$'.length,
        );
        expect(math.latexSourceMap, hasLength(math.latex.length));
        expect(math.latexSourceMap!.first, source.indexOf('x^2 + 1'));
      },
    );

    test(
      r'\efrac, \ds, \sqrtp, \DELTA, \EPSILON, \Par, and \DPtypo normalize inside inline and display math',
      () {
        const source = r'''
Inline $\efrac{1}{2} + \ds\int_0^1 \DPtypo{x^3}{x^2}\,dx + \sqrtp[3]{y} + \DELTA x + \EPSILON + \Par{a+b}$ and display:
\[
\efrac{dy}{dx} = \ds\lim_{\DELTA x \to 0} \DPchg{\frac{y}{x}}{\frac{\DELTA y}{\DELTA x}}
\]
''';
        final blocks = parseLatexDocument(source);
        final para = blocks.whereType<ParagraphBlock>().single;
        final inlineMath = para.spans.whereType<InlineMath>().single;
        expect(
          inlineMath.latex,
          r'\frac{1}{2} + \displaystyle\int_0^1 x^2\,dx + \sqrt[3]{y} + \epsilon x + \delta + (a+b)',
        );
        expect(inlineMath.latexSourceMap, hasLength(inlineMath.latex.length));
        // The kept 'x^2' inside \DPtypo{x^3}{x^2} maps to the second argument's offset.
        final x2Idx = inlineMath.latex.indexOf('x^2');
        expect(inlineMath.latexSourceMap![x2Idx], source.indexOf('x^2'));

        final display = blocks.whereType<DisplayMathBlock>().single;
        expect(
          display.latex,
          r'\frac{dy}{dx} = \displaystyle\lim_{\epsilon x \to 0} \frac{\epsilon y}{\epsilon x}',
        );
        expect(display.latexSourceMap, hasLength(display.latex.length));
      },
    );

    test(
      'DPalign* and DPgather* rewrite to align* and gather* and normalize lintertext, rintertext, intertext, Tag, and displaybreak',
      () {
        const source = r'''
\begin{DPalign*}[m]
y + dy &= (x + dx)^2 \displaybreak[1] \\
\intertext{\indent Now $y = x^2$; subtracting leaves}
dy &= 2x \cdot dx + (dx)^2, \\
\lintertext{and}
\efrac{dy}{dx} &= 2x \Tag{(1)}
\end{DPalign*}
\begin{DPgather*}[a]
\ds\int x^n\,dx = \frac{x^{n+1}}{n+1} + C \\
\lintertext{\rlap{So also}}
\ds\int x^{-1}\,dx = \log x + C
\end{DPgather*}
''';
        final blocks = parseLatexDocument(source);
        final displays = blocks.whereType<DisplayMathBlock>().toList();
        expect(displays, hasLength(2));

        final alignLatex = displays[0].latex;
        expect(alignLatex, startsWith(r'\begin{align*}'));
        expect(alignLatex, endsWith(r'\end{align*}'));
        expect(alignLatex, isNot(contains('DPalign')));
        expect(alignLatex, isNot(contains('[m]')));
        expect(alignLatex, isNot(contains('displaybreak')));
        expect(alignLatex, isNot(contains(r'\lintertext')));
        expect(alignLatex, isNot(contains(r'\intertext')));
        expect(alignLatex, isNot(contains(r'\Tag')));
        expect(alignLatex, isNot(contains(r'$')));
        expect(
          alignLatex,
          contains(r'\text{Now }y = x^2\text{; subtracting leaves} \\'),
        );
        expect(alignLatex, contains(r'\text{and}\quad '));
        expect(alignLatex, contains(r'\frac{dy}{dx} &= 2x \quad\text{(1)}'));
        expect(displays[0].latexSourceMap, hasLength(alignLatex.length));

        final gatherLatex = displays[1].latex;
        expect(gatherLatex, startsWith(r'\begin{gather*}'));
        expect(gatherLatex, endsWith(r'\end{gather*}'));
        expect(gatherLatex, isNot(contains('DPgather')));
        expect(gatherLatex, isNot(contains(r'\rlap')));
        expect(gatherLatex, contains(r'\text{So also}\quad '));
        expect(displays[1].latexSourceMap, hasLength(gatherLatex.length));
      },
    );

    test(
      'Thompson Calculus Made Easy excerpt parses chapters, DPalign*, exercises, and DP notes cleanly',
      () {
        const source = r'''
\Chapter{IV.}{Simplest Cases.}
\First{N}ow let us see how, on first principles, we can differentiate some simple algebraical expression.\Pagelabel{chap4}
\DPPageSep{029.png}{17}%
Let us begin with the simple expression $y=x^2$.
\begin{align*}
y + dy &= (x + dx)^2.
\intertext{\indent Doing the squaring we get:}
y + dy &= x^2 + 2x \cdot dx + (dx)^2.
\end{align*}
\Note{Note to Chapter IV.}
Try to differentiate $\efrac{1}{x^2}$ using \DPtypo{teh}{the} same rule.
\Exercises{III}
\Item{1.} Differentiate $y = x^5$.
''';
        final blocks = parseLatexDocument(source);
        final headings = blocks.whereType<HeadingBlock>().toList();
        expect(headings, hasLength(3));
        expect(
          headings[0].spans.whereType<TextRun>().map((s) => s.text).join(),
          'Chapter IV.: Simplest Cases.',
        );
        expect(
          headings[1].spans.whereType<TextRun>().map((s) => s.text).join(),
          'Note to Chapter IV.',
        );
        expect(
          headings[2].spans.whereType<TextRun>().map((s) => s.text).join(),
          'Exercises III',
        );

        final display = blocks.whereType<DisplayMathBlock>().single;
        expect(
          display.latex,
          contains(r'\\ \text{Doing the squaring we get:} \\'),
        );
        expect(display.latexSourceMap, hasLength(display.latex.length));
      },
    );

    test(
      'Hardy Course of Pure Mathematics excerpt parses Section, Theorem, Examples, and Modernize conditionals',
      () {
        const source = r'''
\ifthenelse{\boolean{Modernize}}{%
  \newcommand{\DELTA}{\delta}%
  \newcommand{\DPchg}[2]{#2}%
}{%
  \newcommand{\DELTA}{\Delta}%
  \newcommand{\DPchg}[2]{#1}%
}
\begin{document}
\Section[Limits of Functions]{Limits of Functions of a Continuous Variable.}
\begin{Theorem}
If $\phi(x) \to A$ as $x \to a$, so that $|\phi(x) - A| < \EPSILON$ whenever $0 < |x - a| \le \DELTA$, then the limit is unique.
\end{Theorem}
\begin{Examples}{X.}
\Item{1.} Prove that $\lim_{x \to 0} \DPchg{\frac{\Sin x}{x}}{\frac{\sin x}{x}} = 1$.
\end{Examples}
\end{document}
''';
        final preamble = extractMacroPreamble(source);
        expect(preamble, isNot(contains('ifthenelse')));
        expect(preamble, isNot(contains('DPchg')));

        final blocks = parseLatexDocument(source);
        expect(blocks.whereType<HeadingBlock>(), hasLength(2));
        final thm = blocks.whereType<TheoremBlock>().single;
        expect(thm.noun, 'Theorem');
        final thmPara = thm.body.whereType<ParagraphBlock>().single;
        final thmMath = thmPara.spans.whereType<InlineMath>().toList();
        expect(thmMath[2].latex, r'|\phi(x) - A| < \delta');
        expect(thmMath[3].latex, r'0 < |x - a| \le \epsilon');

        final lastPara = blocks.whereType<ParagraphBlock>().last;
        final exMath = lastPara.spans.whereType<InlineMath>().single;
        expect(exMath.latex, r'\lim_{x \to 0} \frac{\sin x}{x} = 1');
      },
    );

    test(
      "Euclid's Elements excerpt parses \\mybook, \\myprop, \\mypropl, and \\begin{Defn}",
      () {
        const source = r'''
\mybook{I}{The First Book of the Elements.}
\begin{Defn}
\Item{1.} A \Defn{point} is that which has no part.
\end{Defn}
\myprop{PROPOSITION}{1.}{On a given finite straight line to construct an equilateral triangle.}{fig01}
\mypropl{PROPOSITION}{47.}{prop47}{In right-angled triangles the square on the side subtending the right angle is equal to the squares on the sides containing the right angle.}{fig47}
''';
        final blocks = parseLatexDocument(source);
        final bookHeading = blocks.whereType<HeadingBlock>().single;
        expect(
          bookHeading.spans.whereType<TextRun>().map((s) => s.text).join(),
          'Book I: The First Book of the Elements.',
        );

        final theorems = blocks.whereType<TheoremBlock>().toList();
        expect(theorems, hasLength(3));
        expect(theorems[0].noun, 'Definition');
        expect(theorems[1].noun, 'Proposition');
        expect(theorems[1].number, '1');
        expect(theorems[2].noun, 'Proposition');
        expect(theorems[2].number, '47');
        final pythagorasText = theorems[2].body
            .whereType<ParagraphBlock>()
            .single
            .spans
            .whereType<TextRun>()
            .map((s) => s.text)
            .join();
        expect(
          pythagorasText,
          contains('square on the side subtending the right angle'),
        );
      },
    );

    test(
      'Wentworth Algebra excerpt parses ParTheorem, Problems, Soln, and Answers environments',
      () {
        const source = r'''
\begin{ParTheorem}{Rule for Addition.}
To add two algebraic numbers with like signs, add their absolute values.
\end{ParTheorem}
\begin{Soln}
In $\sqrtp[3]{8x^3} + \Par{2x - 1}$, simplify each term.
\end{Soln}
\begin{Problems}[2]
\Item{1.} Simplify $3x + 5x$.
\end{Problems}
\begin{Answers}[2]{12}{Addition of Monomials}{}
\Ans{1.} $8x$.
\end{Answers}
''';
        final blocks = parseLatexDocument(source);
        final theorems = blocks.whereType<TheoremBlock>().toList();
        expect(theorems, hasLength(2));
        expect(theorems[0].noun, 'Theorem');
        expect(
          theorems[0].title!.whereType<TextRun>().map((s) => s.text).join(),
          'Rule for Addition.',
        );
        expect(theorems[1].noun, 'Solution');
        final solnMath = theorems[1].body
            .whereType<ParagraphBlock>()
            .single
            .spans
            .whereType<InlineMath>()
            .single;
        expect(solnMath.latex, r'\sqrt[3]{8x^3} + (2x - 1)');

        final answerHeading = blocks.whereType<HeadingBlock>().single;
        expect(
          answerHeading.spans.whereType<TextRun>().map((s) => s.text).join(),
          'Exercise 12 — Addition of Monomials',
        );
      },
    );
  });
}
