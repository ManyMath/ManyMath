import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/document_view.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manymath/src/page_setup.dart';
import 'package:manyui/manyui.dart';

void main() {
  testWidgets('zoom scales the whole page, margins included', (tester) async {
    const blocks = <DocBlock>[
      ParagraphBlock(<DocInline>[TextRun('Page body text')]),
    ];

    Future<double> contentWidthAt(double zoom) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MWidgetsApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: DocumentView(blocks: blocks, zoom: zoom),
          ),
        ),
      );
      final canvas = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(SizedBox),
      );
      return tester.getSize(canvas.first).width;
    }

    // At 100% the 760pt page plus its canvas padding determines the
    // canvas width.
    expect(await contentWidthAt(1), 760 + 48);

    // At 140% the page itself grows (760 * 1.4 = 1064, plus canvas
    // padding), outgrowing the viewport like a PDF zoom would.
    expect(await contentWidthAt(1.4), 760 * 1.4 + 48);
  });

  group('packBlocksIntoPages', () {
    test('packs greedily and breaks before a block that does not fit', () {
      expect(
        packBlocksIntoPages(<double>[100, 200, 300, 150], 400),
        <List<int>>[
          <int>[0, 1],
          <int>[2],
          <int>[3],
        ],
      );
    });

    test('an exact fit stays on one page', () {
      expect(packBlocksIntoPages(<double>[250, 250], 500), <List<int>>[
        <int>[0, 1],
      ]);
    });

    test('a block taller than a page gets a page to itself', () {
      expect(packBlocksIntoPages(<double>[100, 900, 100], 500), <List<int>>[
        <int>[0],
        <int>[1],
        <int>[2],
      ]);
    });

    test('empty input yields no pages', () {
      expect(packBlocksIntoPages(const <double>[], 500), isEmpty);
    });
  });

  testWidgets('pages mode splits a long document into page cards', (
    tester,
  ) async {
    // One line of body text is ~37pt with its paragraph spacing; sixty of
    // them overflow Letter's ~960pt content height several times over.
    final blocks = <DocBlock>[
      for (var i = 1; i <= 60; i++)
        ParagraphBlock(<DocInline>[TextRun('Line $i of the document body.')]),
    ];

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MWidgetsApp(
        home: SizedBox(
          width: 1400,
          height: 1000,
          child: DocumentView(blocks: blocks, pageSize: PageSize.usLetter),
        ),
      ),
    );
    // First frame renders the offstage measure pass; the pages appear after
    // the post-frame measurement lands.
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 3 of 3'), findsOneWidget);
    expect(find.text('No rendered content'), findsNothing);
  });

  testWidgets('theorem notes and proof titles read as amsthm sets them', (
    tester,
  ) async {
    const blocks = <DocBlock>[
      TheoremBlock(
        noun: 'Theorem',
        number: '1',
        title: <DocInline>[TextRun('Main')],
        body: <DocBlock>[
          ParagraphBlock(<DocInline>[TextRun('Body.')]),
        ],
      ),
      TheoremBlock(
        noun: 'Proof',
        title: <DocInline>[TextRun('Proof of the main theorem')],
        body: <DocBlock>[
          ParagraphBlock(<DocInline>[TextRun('Argument.')]),
        ],
      ),
    ];
    await tester.pumpWidget(
      const MWidgetsApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: DocumentView(blocks: blocks),
        ),
      ),
    );
    await tester.pump();

    final texts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((text) => text.text.toPlainText())
        .toList();
    expect(texts, contains('Theorem 1 (Main). Body.'));
    expect(texts, contains('Proof of the main theorem. Argument. ∎'));
  });

  testWidgets('a TikZ diagram renders its nodes and edge labels', (
    tester,
  ) async {
    final blocks = parseLatexDocument(
      '\\begin{tikzpicture}\n'
      r'\node[draw] (a) at (0,0) {Alpha}; \node[draw] (b) at (5,0) {Beta};'
      r'\draw[->] (a) -- node[above] {gamma} (b);'
      '\n\\end{tikzpicture}\n',
    );
    await tester.pumpWidget(
      MWidgetsApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: DocumentView(blocks: blocks),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Alpha', findRichText: true), findsOneWidget);
    expect(find.text('Beta', findRichText: true), findsOneWidget);
    expect(find.text('gamma', findRichText: true), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'TikZ diagram: 2 nodes, 1 edges',
      ),
      findsOneWidget,
    );
  });

  testWidgets('select all in pages mode copies the document once', (
    tester,
  ) async {
    const blocks = <DocBlock>[
      ParagraphBlock(<DocInline>[TextRun('First paragraph.')]),
      ParagraphBlock(<DocInline>[TextRun('Second paragraph.')]),
    ];
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MWidgetsApp(
        home: SizedBox(
          width: 1400,
          height: 1000,
          child: DocumentView(blocks: blocks, pageSize: PageSize.usLetter),
        ),
      ),
    );
    // Pages appear after the post-frame measurement; the page text then
    // registers with the selection region over the following frames.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final region = tester.state<SelectableRegionState>(
      find.descendant(
        of: find.byType(DocumentView),
        matching: find.byType(SelectableRegion),
      ),
    );
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pump();
    // The copy shortcut and context menu both end in this call.
    // ignore: deprecated_member_use
    region.copySelection(SelectionChangedCause.keyboard);
    await tester.pump();

    // Neither the offstage measurement column nor the page number is text
    // of the document.
    expect(copied, 'First paragraph.Second paragraph.');
  });
}
