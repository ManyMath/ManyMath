import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manymath/src/page_setup.dart';
import 'package:manymath/src/print.dart';
import 'package:manymath/src/print_document.dart';

void main() {
  String htmlFor(
    List<DocBlock> blocks, {
    PageSize pageSize = PageSize.usLetter,
    Map<String, String> svgs = const <String, String>{},
  }) => buildPrintHtml(
    title: 'Test <Paper> & "Friends"',
    blocks: blocks,
    pageSize: pageSize,
    formulaSvgs: svgs,
    fontBaseUrl: 'https://example.test/edit/assets/fonts/',
  );

  test('fonts resolve under the base href with or without a slash', () {
    // The editor's base href is /edit/ whether the reader opened /edit/
    // or /edit; the document base URL is the same either way.
    expect(
      fontBaseUrlFor('https://manymath.com/edit/'),
      'https://manymath.com/edit/assets/fonts/',
    );
    expect(
      fontBaseUrlFor('https://manymath.com/edit/index.html'),
      'https://manymath.com/edit/assets/fonts/',
    );
  });

  test('escapes HTML in the title and text runs', () {
    final html = htmlFor(const <DocBlock>[
      ParagraphBlock(<DocInline>[TextRun('a < b & c > d')]),
    ]);
    expect(html, contains('a &lt; b &amp; c &gt; d'));
    expect(html, contains('Test &lt;Paper&gt; &amp; &quot;Friends&quot;'));
    expect(html, isNot(contains('Test <Paper>')));
  });

  test('maps inline styles to semantic tags', () {
    final html = htmlFor(const <DocBlock>[
      ParagraphBlock(<DocInline>[
        TextRun('bold', bold: true),
        TextRun(' '),
        TextRun('ital', italic: true),
        TextRun(' '),
        TextRun('mono', monospace: true),
      ]),
    ]);
    expect(html, contains('<strong>bold</strong>'));
    expect(html, contains('<em>ital</em>'));
    expect(html, contains('<code>mono</code>'));
  });

  test('declares the requested page size for the print dialog', () {
    expect(htmlFor(const <DocBlock>[]), contains('@page { size: Letter;'));
    expect(
      htmlFor(const <DocBlock>[], pageSize: PageSize.a4),
      contains('@page { size: A4;'),
    );
  });

  test('embeds pre-rendered formula SVGs and falls back to code', () {
    const blocks = <DocBlock>[
      ParagraphBlock(<DocInline>[InlineMath(r'x^2')]),
      DisplayMathBlock(r'\frac{a}{b}'),
    ];
    final html = htmlFor(
      blocks,
      svgs: <String, String>{
        formulaKey(r'x^2', false): '<svg>inline</svg>',
        formulaKey(r'\frac{a}{b}', true): '<svg>display</svg>',
      },
    );
    expect(html, contains('<svg>inline</svg>'));
    expect(
      html,
      contains('<div class="formula-display"><svg>display</svg></div>'),
    );

    final missing = htmlFor(blocks);
    expect(missing, contains('<code>x^2</code>'));
    expect(missing, contains('<pre>\\frac{a}{b}</pre>'));
  });

  test('renders headings, lists, and tables as structural HTML', () {
    final html = htmlFor(const <DocBlock>[
      HeadingBlock(1, <DocInline>[TextRun('Section')]),
      HeadingBlock(3, <DocInline>[TextRun('Subsubsection')]),
      ListBlock(
        style: ListStyle.numbered,
        items: <List<DocBlock>>[
          <DocBlock>[
            ParagraphBlock(<DocInline>[TextRun('first')]),
          ],
        ],
      ),
      TableBlock(<List<TableCellData>>[
        <TableCellData>[
          TableCellData(<DocInline>[TextRun('wide')], colSpan: 2),
          TableCellData(<DocInline>[TextRun('cell')]),
        ],
      ]),
    ]);
    expect(html, contains('<h1>Section</h1>'));
    expect(html, contains('<h3>Subsubsection</h3>'));
    expect(html, contains('<ol><li><p>first</p></li></ol>'));
    expect(html, contains('<td colspan="2">wide</td>'));
    expect(html, contains('<td>cell</td>'));
  });

  test('prints title metadata with the document macros expanded', () {
    final html = htmlFor(
      parseLatexDocument(r'''
\newcommand{\Product}{ManyMath}
\title{\Product{} Notes}
\date{Draft}
\begin{document}\maketitle\end{document}
'''),
    );
    expect(html, contains('<h1 class="title">ManyMath Notes</h1>'));
    expect(html, contains('<p class="date">Draft</p>'));
  });

  test('escapes theorem nouns and numbers from the document', () {
    final html = htmlFor(const <DocBlock>[
      TheoremBlock(
        noun: '<img src=x onerror=alert(1)>',
        number: '1',
        body: <DocBlock>[
          ParagraphBlock(<DocInline>[TextRun('body')]),
        ],
      ),
    ]);
    expect(html, isNot(contains('<img')));
    expect(html, contains('&lt;img src=x onerror=alert(1)&gt; 1.'));
  });

  test('theorem notes and proof titles read as amsthm sets them', () {
    final html = htmlFor(const <DocBlock>[
      TheoremBlock(
        noun: 'Theorem',
        number: '1',
        title: <DocInline>[TextRun('Main')],
        body: <DocBlock>[
          ParagraphBlock(<DocInline>[TextRun('body')]),
        ],
      ),
      TheoremBlock(
        noun: 'Proof',
        title: <DocInline>[TextRun('Proof of the main theorem')],
        body: <DocBlock>[
          ParagraphBlock(<DocInline>[TextRun('argument')]),
        ],
      ),
    ]);
    expect(
      html,
      contains('<p><strong>Theorem 1</strong> (Main)<strong>.</strong> body'),
    );
    expect(html, contains('<p><em>Proof of the main theorem.</em> argument'));
  });

  test('closes the theorem label before a non-paragraph body', () {
    final html = htmlFor(const <DocBlock>[
      TheoremBlock(
        noun: 'Lemma',
        number: '2',
        body: <DocBlock>[DisplayMathBlock('x')],
      ),
    ]);
    expect(html, contains('<p><strong>Lemma 2.</strong> </p><pre>x</pre>'));
  });

  test('prints a supported TikZ diagram as a scalable SVG', () {
    final blocks = parseLatexDocument(
      '\\begin{tikzpicture}\n'
      r'\node[draw, rounded corners] (a) at (0,0) {Start};'
      r'\node[draw] (b) at (4,0) {$x^2$};'
      r'\draw[->, thick] (a) -- node[above] {step} (b);'
      '\n\\end{tikzpicture}\n',
    );
    final html = htmlFor(
      blocks,
      svgs: <String, String>{
        formulaKey('x^2', false):
            '<svg xmlns="http://www.w3.org/2000/svg" width="12pt" '
            'height="9pt"><g/></svg>',
      },
    );
    expect(html, isNot(contains('TikZ diagram omitted')));
    expect(
      html,
      contains('<svg role="img" aria-label="TikZ diagram: 2 nodes, 1 edges"'),
    );
    expect('<rect '.allMatches(html), hasLength(2));
    expect(html, contains('rx="'), reason: 'rounded corners');
    expect('<line '.allMatches(html), hasLength(1));
    expect('<polygon '.allMatches(html), hasLength(1), reason: 'arrowhead');
    expect(html, contains('>Start</div></foreignObject>'));
    expect(html, contains('<div class="tikz-text halo"'));
    expect(html, contains('>step</div></foreignObject>'));
    expect(html, contains('width="12pt" height="9pt"'), reason: 'label math');
  });

  test('diagrams degrade to an explanatory note, not a crash', () {
    final html = htmlFor(const <DocBlock>[DiagramBlock('tikz', 'ignored')]);
    expect(html, contains('omitted from print'));
  });
}
