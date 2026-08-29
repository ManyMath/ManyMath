import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manymath/src/page_setup.dart';
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
      ListBlock(style: ListStyle.numbered, items: <List<DocBlock>>[
        <DocBlock>[ParagraphBlock(<DocInline>[TextRun('first')])],
      ]),
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

  test('diagrams degrade to an explanatory note, not a crash', () {
    final html = htmlFor(const <DocBlock>[
      DiagramBlock('tikz', 'ignored'),
    ]);
    expect(html, contains('omitted from print'));
  });
}
