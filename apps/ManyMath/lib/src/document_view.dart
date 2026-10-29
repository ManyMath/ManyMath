import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ratex/ratex.dart';

import 'latex_document.dart';
import 'page_setup.dart';
import 'preview_theme.dart';
import 'tikz_diagram.dart';

/// The bundled brand code face, first in every monospace stack so `\texttt`
/// runs, code blocks, and TikZ typewriter labels render identically on every
/// host; the generic families behind it only serve where it failed to load.
const String monoFontFamily = 'JetBrains Mono';
const List<String> monoFontFallback = <String>[
  'ui-monospace',
  'Menlo',
  'Consolas',
  'monospace',
];

/// Monospace runs render slightly below the surrounding size: JetBrains
/// Mono's x-height is much taller than Latin Modern's, so equal point sizes
/// make `\texttt` look bigger than the prose it sits in.
const double monoFontScale = 0.88;

class DocumentView extends StatefulWidget {
  const DocumentView({
    required this.blocks,
    this.macroPreamble = '',
    this.zoom = 1,
    this.previewTheme = PreviewTheme.light,
    this.fontFamily = 'Latin Modern Roman',
    this.pageSize,
    super.key,
  });

  final List<DocBlock> blocks;

  /// `\providecommand`/`\def` statements collected from the whole document
  /// (see `extractMacroPreamble`), prepended to every formula so RaTeX's
  /// macro expander can resolve the paper's own macros.
  final String macroPreamble;
  final double zoom;

  /// The document's color scheme, derived from the app-wide theme; the
  /// light palette doubles as the export default (black ink on white).
  final PreviewTheme previewTheme;

  /// The prose face, chosen by the preview pane's font dropdown. Math
  /// keeps its KaTeX fonts regardless.
  final String fontFamily;

  /// When null (the default), the document renders as one continuous
  /// scroll. When set, it is paginated into discrete pages of that size.
  final PageSize? pageSize;

  @override
  State<DocumentView> createState() => _DocumentViewState();
}

/// Greedy first-fit pagination: packs [heights] (per-block, in document
/// order) into pages of [capacity] height, returning the block indexes of
/// each page. A block taller than a page gets one to itself and overflows
/// visually (the page card clips it), the way a PDF shows an oversized
/// figure rather than splitting it.
List<List<int>> packBlocksIntoPages(List<double> heights, double capacity) {
  final pages = <List<int>>[];
  var current = <int>[];
  var used = 0.0;
  for (var i = 0; i < heights.length; i++) {
    if (current.isNotEmpty && used + heights[i] > capacity) {
      pages.add(current);
      current = <int>[];
      used = 0.0;
    }
    current.add(i);
    used += heights[i];
  }
  if (current.isNotEmpty) pages.add(current);
  return pages;
}

class _DocumentViewState extends State<DocumentView> {
  // Shadowing getters keep the rendering helpers below written against the
  // old stateless field names.
  List<DocBlock> get blocks => widget.blocks;
  String get macroPreamble => widget.macroPreamble;
  double get zoom => widget.zoom;
  String get fontFamily => widget.fontFamily;

  double get _bodySize => 16 * zoom;
  PreviewPalette get _palette => previewPalette(widget.previewTheme);

  /// Pagination results for the current inputs; null while the measurement
  /// pass has not run (or after an invalidation).
  List<List<int>>? _pages;
  List<GlobalKey>? _measureKeys;
  bool _measurePending = false;
  Timer? _verifyTimer;

  /// Heights from the last measurement, so verification can tell whether
  /// formulas and fonts have finished changing the layout.
  List<double>? _measuredHeights;
  int _verifyPasses = 0;

  /// Formulas render asynchronously and bundled fonts resolve after first
  /// paint, so pagination re-measures until two passes agree, bounded so a
  /// never-settling layout does not re-measure forever.
  static const int _maxVerifyPasses = 8;

  @override
  void dispose() {
    _verifyTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blocks != widget.blocks ||
        oldWidget.macroPreamble != widget.macroPreamble ||
        oldWidget.zoom != widget.zoom ||
        oldWidget.previewTheme != widget.previewTheme ||
        oldWidget.fontFamily != widget.fontFamily ||
        oldWidget.pageSize != widget.pageSize) {
      _pages = null;
      _measureKeys = null;
      _measuredHeights = null;
      _verifyTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Rendered document preview',
      child: SelectableRegion(
        // manyui's app shell (MWidgetsApp) is widgets-level, not
        // MaterialApp, so it has no MaterialLocalizations ancestor —
        // SelectionArea requires one and would throw. SelectableRegion is
        // the same underlying mechanism without that requirement; the
        // tradeoff is no built-in selection handles/context menu, just
        // click-drag selection and the OS/browser copy shortcut.
        selectionControls: emptyTextSelectionControls,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            final canvasPadding = compact
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 20)
                : const EdgeInsets.symmetric(horizontal: 24, vertical: 30);
            final textStyle = TextStyle(
              color: _palette.ink,
              fontSize: _bodySize,
              height: 1.55,
              fontFamily: fontFamily,
              fontFamilyFallback: fontFamily == monoFontFamily
                  ? monoFontFallback
                  : const <String>[
                      'Georgia',
                      'Times New Roman',
                      'Noto Serif',
                      'serif',
                    ],
            );
            final pageSize = widget.pageSize;
            if (pageSize == null) {
              return _buildContinuous(
                constraints,
                compact,
                canvasPadding,
                textStyle,
              );
            }
            return _buildPaged(constraints, canvasPadding, textStyle, pageSize);
          },
        ),
      ),
    );
  }

  Widget _buildContinuous(
    BoxConstraints constraints,
    bool compact,
    EdgeInsets canvasPadding,
    TextStyle textStyle,
  ) {
    // Zoom is a page-level zoom, like a PDF viewer's: the page itself
    // (margins included) scales, and once it outgrows the viewport the
    // canvas scrolls horizontally.
    final paperPadding = (compact ? 24.0 : 48.0) * zoom;
    final pageWidth = 760 * zoom;
    final contentWidth = math.max(
      constraints.maxWidth,
      pageWidth + 2 * canvasPadding.left,
    );
    final centeredHorizontalPadding = math.max(
      canvasPadding.left,
      (contentWidth - pageWidth) / 2,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: contentWidth,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                centeredHorizontalPadding,
                canvasPadding.top,
                centeredHorizontalPadding,
                canvasPadding.bottom,
              ),
              sliver: DecoratedSliver(
                decoration: BoxDecoration(
                  color: _palette.paper,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: _palette.border),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                sliver: SliverPadding(
                  padding: EdgeInsets.all(paperPadding),
                  sliver: blocks.isEmpty
                      ? SliverToBoxAdapter(
                          child: DefaultTextStyle(
                            style: textStyle,
                            child: Text(
                              'No rendered content',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _palette.dimText),
                            ),
                          ),
                        )
                      : SliverList.builder(
                          itemCount: blocks.length,
                          itemBuilder: (context, index) => DefaultTextStyle(
                            style: textStyle,
                            child: _buildBlock(context, blocks[index]),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Discrete fixed-size pages. Flutter has no flow-into-pages primitive,
  /// so pagination is two-pass: an invisible [Offstage] measure column
  /// reports each block's rendered height at the page's content width,
  /// [packBlocksIntoPages] splits greedily, and the pages render as cards.
  /// The measure column stays in the tree so a re-invalidation (edit, zoom,
  /// page size) can measure again, and so a delayed verify can catch text
  /// that re-laid-out once a late-loading font arrived.
  Widget _buildPaged(
    BoxConstraints constraints,
    EdgeInsets canvasPadding,
    TextStyle textStyle,
    PageSize pageSize,
  ) {
    final pageWidth = pageSize.width * zoom;
    final pageHeight = pageSize.height * zoom;
    final paperPadding = 48.0 * zoom;
    final contentWidth = pageWidth - 2 * paperPadding;
    final contentHeight = pageHeight - 2 * paperPadding;

    final outerWidth = math.max(
      constraints.maxWidth,
      pageWidth + 2 * canvasPadding.left,
    );
    final centeredHorizontalPadding = math.max(
      canvasPadding.left,
      (outerWidth - pageWidth) / 2,
    );

    if (blocks.isNotEmpty && _measureKeys == null) {
      _measureKeys = <GlobalKey>[
        for (var i = 0; i < blocks.length; i++) GlobalKey(),
      ];
      _scheduleMeasurement(contentHeight);
    }
    final measureKeys = _measureKeys;
    final pages = _pages;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: outerWidth,
        // The vertical viewport: the page stack is taller than the window,
        // so it scrolls like the continuous mode's CustomScrollView.
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Stack(
              children: <Widget>[
                if (measureKeys != null)
                  // Offstage skips paint and hit tests but still registers
                  // with the enclosing SelectableRegion, so without this
                  // select-all would copy the document twice.
                  SelectionContainer.disabled(
                    child: Offstage(
                      // The scroll wrapper hands the measure column unbounded
                      // height, so every block lays out at its natural size
                      // (a bare Column would overflow the stack's bound).
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: contentWidth,
                          child: DefaultTextStyle(
                            style: textStyle,
                            child: Column(
                              children: <Widget>[
                                for (var i = 0; i < blocks.length; i++)
                                  Container(
                                    key: measureKeys[i],
                                    child: _buildBlock(context, blocks[i]),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    centeredHorizontalPadding,
                    canvasPadding.top,
                    centeredHorizontalPadding,
                    canvasPadding.bottom,
                  ),
                  child: blocks.isEmpty
                      ? SizedBox(
                          width: pageWidth,
                          child: DefaultTextStyle(
                            style: textStyle,
                            child: Text(
                              'No rendered content',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _palette.dimText),
                            ),
                          ),
                        )
                      : pages == null
                      ? SizedBox(width: pageWidth, height: pageHeight)
                      : Column(
                          children: <Widget>[
                            for (var p = 0; p < pages.length; p++) ...<Widget>[
                              if (p > 0) SizedBox(height: 24 * zoom),
                              _pageCard(
                                pageWidth,
                                pageHeight,
                                paperPadding,
                                pages[p],
                                p,
                                pages.length,
                                textStyle,
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageCard(
    double pageWidth,
    double pageHeight,
    double paperPadding,
    List<int> blockIndexes,
    int pageIndex,
    int pageCount,
    TextStyle textStyle,
  ) {
    return Semantics(
      container: true,
      label: 'Page ${pageIndex + 1} of $pageCount',
      child: Container(
        width: pageWidth,
        height: pageHeight,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: _palette.paper,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: _palette.border),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(paperPadding),
                // The blocks sum to at most the content height, but a stray
                // oversized block must not throw a flex overflow: the scroll
                // wrapper gives the column unbounded height and clips it
                // (unscrollable), matching the printed page's hard edge.
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: DefaultTextStyle(
                    style: textStyle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final i in blockIndexes)
                          _buildBlock(context, blocks[i]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: paperPadding * 0.3,
              child: ExcludeSemantics(
                child: SelectionContainer.disabled(
                  child: Text(
                    '${pageIndex + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _palette.dimText,
                      fontSize: 12 * zoom,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleMeasurement(double capacity) {
    if (_measurePending) return;
    _measurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurePending = false;
      if (!mounted || widget.pageSize == null) return;
      _captureHeights(capacity, scheduleVerify: true);
    });
  }

  void _captureHeights(double capacity, {required bool scheduleVerify}) {
    final keys = _measureKeys;
    if (keys == null) return;
    final heights = <double>[
      for (final key in keys) key.currentContext?.size?.height ?? 0,
    ];
    if (heights.any((height) => height <= 0)) {
      // The measure column has not laid out yet; try again next frame.
      _scheduleMeasurement(capacity);
      return;
    }
    final settled =
        _measuredHeights != null && listEquals(_measuredHeights, heights);
    _measuredHeights = heights;
    // Rebuild even when the heights settled: the page text only registers
    // with the selection region on a build after the measurement pass.
    final pages = packBlocksIntoPages(heights, capacity);
    setState(() => _pages = pages);
    if (scheduleVerify) _verifyPasses = 0;
    if (settled || _verifyPasses >= _maxVerifyPasses) return;
    _verifyPasses++;
    _verifyTimer?.cancel();
    _verifyTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || widget.pageSize == null || _measureKeys == null) {
        return;
      }
      _captureHeights(capacity, scheduleVerify: false);
    });
  }

  Widget _formula(
    BuildContext context,
    String latex, {
    required double fontSize,
    bool displayMode = true,
  }) {
    return RatexMath(
      macroPreamble + latex,
      fontSize: fontSize,
      displayMode: displayMode,
      color: _palette.ink,
      semanticLabel: 'Math formula: $latex',
      loadingBuilder: (_) => SizedBox(height: fontSize),
      errorBuilder: (_, error) => Text(
        'Formula error: ${error.message}',
        style: TextStyle(
          color: _palette.error,
          fontFamily: monoFontFamily,
          fontFamilyFallback: monoFontFallback,
          fontSize: fontSize * 0.68,
        ),
      ),
    );
  }

  Widget _buildBlock(BuildContext context, DocBlock block) {
    switch (block) {
      case TitleBlock():
        Widget metadata(
          List<DocInline> spans,
          double fontSize,
          TextStyle style,
        ) {
          return Text.rich(
            TextSpan(children: _inlineSpans(context, spans, fontSize)),
            textAlign: TextAlign.center,
            style: style,
          );
        }

        final title = block.titleInlines;
        final author = block.authorInlines;
        final date = block.dateInlines;

        return Padding(
          padding: EdgeInsets.only(bottom: 24 * zoom),
          child: Column(
            children: <Widget>[
              if (title != null)
                Semantics(
                  header: true,
                  headingLevel: 2,
                  child: metadata(
                    title,
                    28 * zoom,
                    TextStyle(
                      fontSize: 28 * zoom,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (author != null)
                Padding(
                  padding: EdgeInsets.only(top: 8 * zoom),
                  child: metadata(
                    author,
                    _bodySize,
                    TextStyle(fontSize: _bodySize),
                  ),
                ),
              if (date != null)
                Padding(
                  padding: EdgeInsets.only(top: 4 * zoom),
                  child: metadata(
                    date,
                    _bodySize,
                    TextStyle(fontSize: _bodySize, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        );
      case HeadingBlock():
        final size = switch (block.level) {
          1 => 24.0 * zoom,
          2 => 20.0 * zoom,
          _ => 17.0 * zoom,
        };
        return Semantics(
          header: true,
          headingLevel: switch (block.level) {
            1 => 3,
            2 => 4,
            _ => 5,
          },
          child: Padding(
            padding: EdgeInsets.only(top: 20 * zoom, bottom: 8 * zoom),
            child: Text.rich(
              TextSpan(children: _inlineSpans(context, block.spans, size)),
              style: TextStyle(
                fontSize: size,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      case ParagraphBlock():
        return Padding(
          padding: EdgeInsets.only(bottom: 12 * zoom),
          child: Text.rich(
            TextSpan(children: _inlineSpans(context, block.spans, _bodySize)),
          ),
        );
      case DisplayMathBlock():
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 12 * zoom),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _formula(context, block.latex, fontSize: _bodySize * 1.25),
            ),
          ),
        );
      case ListBlock():
        return Padding(
          padding: EdgeInsets.only(bottom: 12 * zoom, left: 8 * zoom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final (index, item) in block.items.indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: 4 * zoom),
                  child: block.style == ListStyle.description
                      ? _blockColumn(context, item)
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: 28 * zoom,
                              child: Text(
                                block.style == ListStyle.numbered
                                    ? '${index + 1}.'
                                    : '•',
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(width: 8 * zoom),
                            Expanded(child: _blockColumn(context, item)),
                          ],
                        ),
                ),
            ],
          ),
        );
      case CodeBlock():
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8 * zoom),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(12 * zoom),
            decoration: BoxDecoration(
              color: _palette.panel,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _palette.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                block.code,
                style: TextStyle(
                  fontFamily: monoFontFamily,
                  fontFamilyFallback: monoFontFallback,
                  fontSize: _bodySize * 0.85,
                  height: 1.4,
                ),
              ),
            ),
          ),
        );
      case BibliographyBlock():
        return Padding(
          padding: EdgeInsets.only(bottom: 12 * zoom, left: 8 * zoom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final entry in block.entries)
                Padding(
                  padding: EdgeInsets.only(bottom: 6 * zoom),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 36 * zoom,
                        child: Text('[${entry.number}]'),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: _inlineSpans(
                              context,
                              entry.spans,
                              _bodySize,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case TableBlock():
        final columnCount = block.rows
            .map((row) => row.fold<int>(0, (sum, cell) => sum + cell.colSpan))
            .fold<int>(0, (a, b) => a > b ? a : b);
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8 * zoom),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: _palette.border),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: <TableRow>[
                for (final row in block.rows)
                  TableRow(
                    children: <Widget>[
                      // Flutter's Table has no real colspan: a spanning
                      // cell's content sits in its first column and the
                      // spanned remainder renders as empty cells.
                      for (final cell in row) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10 * zoom,
                            vertical: 6 * zoom,
                          ),
                          // Cap the cell width so a prose-length cell wraps
                          // (LaTeX p{...} columns do the same) instead of
                          // stretching the table far past the page.
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 300 * zoom),
                            child: Text.rich(
                              TextSpan(
                                children: _inlineSpans(
                                  context,
                                  cell.spans,
                                  _bodySize * 0.95,
                                ),
                              ),
                            ),
                          ),
                        ),
                        for (var s = 1; s < cell.colSpan; s++)
                          const SizedBox.shrink(),
                      ],
                      for (
                        var c = row.fold<int>(
                          0,
                          (sum, cell) => sum + cell.colSpan,
                        );
                        c < columnCount;
                        c++
                      )
                        const SizedBox.shrink(),
                    ],
                  ),
              ],
            ),
          ),
        );
      case CenterBlock():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            for (final child in block.children) _buildBlock(context, child),
          ],
        );
      case FramedBlock():
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8 * zoom),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(12 * zoom),
            decoration: BoxDecoration(
              border: Border.all(color: _palette.frameBorder),
            ),
            child: _blockColumn(context, block.children),
          ),
        );
      case CaptionBlock():
        return Padding(
          padding: EdgeInsets.only(top: 4 * zoom, bottom: 10 * zoom),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '${block.label}: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                ..._inlineSpans(context, block.spans, _bodySize * 0.9),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: _bodySize * 0.9),
          ),
        );
      case DiagramBlock():
        return _diagramPlaceholder(block.kind);
      case TikzDiagramBlock():
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 10 * zoom),
          child: _buildTikz(context, block.diagram),
        );
      case FootnoteBlock():
        return Padding(
          padding: EdgeInsets.only(top: 2 * zoom, bottom: 2 * zoom),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: '${block.number}. '),
                ..._inlineSpans(context, block.spans, _bodySize * 0.85),
              ],
            ),
            style: TextStyle(fontSize: _bodySize * 0.85),
          ),
        );
      case QuoteBlock():
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 6 * zoom),
          child: Container(
            padding: EdgeInsets.only(left: 16 * zoom),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: _palette.border, width: 3),
              ),
            ),
            child: _blockColumn(context, block.children),
          ),
        );
      case TheoremBlock():
        // \begin{proof} is conventionally unboxed and unnumbered: an
        // italicized "Proof." label, the argument, and a trailing QED mark
        // instead of a bold "Noun N." in a bordered box.
        final isProof = block.noun == 'Proof';
        // The label (and optional [title]) run in with the body's first
        // paragraph, matching amsthm's run-in heading; block-level body
        // content (display math, lists) follows below.
        final body = block.body;
        final runIn = body.isNotEmpty && body.first is ParagraphBlock;
        final rest = runIn ? body.sublist(1) : body;
        final qedRunIn = isProof && runIn && rest.isEmpty;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  // amsthm: "Theorem 1 (Title)." with the note upright, and
                  // a proof's optional title replaces the word "Proof".
                  if (isProof)
                    TextSpan(
                      children: <InlineSpan>[
                        if (block.title != null)
                          ..._inlineSpans(context, block.title!, _bodySize)
                        else
                          const TextSpan(text: 'Proof'),
                        const TextSpan(text: '. '),
                      ],
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    )
                  else ...[
                    TextSpan(
                      text: block.number == null
                          ? block.noun
                          : '${block.noun} ${block.number}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (block.title != null)
                      TextSpan(
                        children: <InlineSpan>[
                          const TextSpan(text: ' ('),
                          ..._inlineSpans(context, block.title!, _bodySize),
                          const TextSpan(text: ')'),
                        ],
                      ),
                    const TextSpan(
                      text: '. ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  if (runIn)
                    ..._inlineSpans(
                      context,
                      (body.first as ParagraphBlock).spans,
                      _bodySize,
                    ),
                  if (qedRunIn) const TextSpan(text: ' ∎'),
                ],
              ),
            ),
            for (final child in rest) _buildBlock(context, child),
            if (isProof && !qedRunIn)
              const Align(alignment: Alignment.centerRight, child: Text('∎')),
          ],
        );
        return isProof
            ? Padding(
                padding: EdgeInsets.symmetric(vertical: 6 * zoom),
                child: content,
              )
            : Padding(
                padding: EdgeInsets.symmetric(vertical: 8 * zoom),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12 * zoom),
                  decoration: BoxDecoration(
                    color: _palette.panel,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _palette.border),
                  ),
                  child: content,
                ),
              );
    }
  }

  /// A nested block sequence (list item, quote body) laid out vertically.
  Widget _blockColumn(BuildContext context, List<DocBlock> blocks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final block in blocks) _buildBlock(context, block),
      ],
    );
  }

  List<InlineSpan> _inlineSpans(
    BuildContext context,
    List<DocInline> spans,
    double fontSize,
  ) {
    return <InlineSpan>[
      for (final span in spans)
        switch (span) {
          TextRun() => TextSpan(
            text: span.text,
            style: TextStyle(
              fontWeight: span.bold ? FontWeight.w700 : null,
              fontStyle: span.italic ? FontStyle.italic : null,
              fontFamily: span.monospace ? monoFontFamily : null,
              fontFamilyFallback: span.monospace ? monoFontFallback : null,
              fontSize: span.monospace ? fontSize * monoFontScale : null,
              decoration: span.underline ? TextDecoration.underline : null,
            ),
          ),
          InlineMath() => WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _formula(
              context,
              span.latex,
              fontSize: fontSize,
              displayMode: false,
            ),
          ),
        },
    ];
  }

  Widget _diagramPlaceholder(String kind) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * zoom),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16 * zoom),
        decoration: BoxDecoration(
          color: _palette.panel,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _palette.border),
        ),
        child: Text(
          'Preview unavailable for this $kind diagram',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _palette.dimText,
            fontStyle: FontStyle.italic,
            fontSize: _bodySize * 0.9,
          ),
        ),
      ),
    );
  }

  /// One TikZ label (node or edge) as a single multi-line rich text: lines
  /// joined by `\n`, each line through the document's inline pipeline so
  /// `\_`, ligatures, `\ttfamily`, and math render like the surrounding
  /// prose.
  TextSpan _tikzLabelSpan(
    BuildContext context,
    List<String> lines,
    double fontSize, {
    bool monospace = false,
  }) {
    return TextSpan(
      children: <InlineSpan>[
        for (final (index, line) in lines.indexed) ...[
          if (index > 0) const TextSpan(text: '\n'),
          ..._inlineSpans(
            context,
            parseInline(line, monospace: monospace),
            fontSize,
          ),
        ],
      ],
      style: TextStyle(
        fontSize: fontSize,
        height: 1.3,
        fontFamily: monospace ? monoFontFamily : null,
        fontFamilyFallback: monospace ? monoFontFallback : null,
        color: _palette.ink,
      ),
    );
  }

  Size _measureSpan(TextSpan span) {
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    // Math labels arrive as WidgetSpans, which TextPainter cannot size
    // itself; a square placeholder per formula keeps the measurement sane.
    final placeholders = _countPlaceholders(span);
    if (placeholders > 0) {
      final side = span.style?.fontSize ?? 14;
      painter.setPlaceholderDimensions(<PlaceholderDimensions>[
        for (var i = 0; i < placeholders; i++)
          PlaceholderDimensions(
            size: Size(side, side),
            alignment: PlaceholderAlignment.middle,
          ),
      ]);
    }
    painter.layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }

  static int _countPlaceholders(InlineSpan span) {
    var count = 0;
    span.visitChildren((child) {
      if (child is WidgetSpan) count++;
      return true;
    });
    return count;
  }

  /// Draws a parsed TikZ picture: absolutely positioned rounded-rect nodes
  /// over a [CustomPaint] that strokes the edges border-to-border, scaled
  /// down when wider than the page (horizontal scroll below 55%, like
  /// tables).
  Widget _buildTikz(BuildContext context, TikzDiagram diagram) {
    final pxPerCm = 35.0 * zoom;
    final nodeFontSize = 12.0 * zoom;
    final edgeFontSize = 10.5 * zoom;

    final nodeSpans = <String, TextSpan>{
      for (final node in diagram.nodes)
        node.name: _tikzLabelSpan(
          context,
          node.labelLines,
          nodeFontSize,
          monospace: node.style.monospace,
        ),
    };

    final labelSpans = Map<TikzEdgeLabel, TextSpan>.identity();
    final layout = layoutTikzDiagram(
      diagram,
      pxPerCm: pxPerCm,
      measureNode: (node) => _measureSpan(nodeSpans[node.name]!),
      measureEdgeLabel: (label) => _measureSpan(
        labelSpans[label] = _tikzLabelSpan(context, label.lines, edgeFontSize),
      ),
      labelGap: 4.0 * zoom,
      margin: 4.0 * zoom,
    );
    // The parser rejects unresolvable placements, so this cannot fail; keep
    // the placeholder as a defensive fallback rather than throwing.
    if (layout == null) return _diagramPlaceholder('tikzpicture');
    final natural = layout.size;

    final diagramBody = SizedBox(
      width: natural.width,
      height: natural.height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _TikzEdgePainter(
                edges: layout.edges,
                ink: _palette.ink,
                zoom: zoom,
              ),
            ),
          ),
          for (final node in diagram.nodes)
            Positioned.fromRect(
              rect: layout.nodes[node.name]!,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _palette.paper,
                  border: node.style.draw
                      ? Border.all(color: _palette.ink, width: 1.1 * zoom)
                      : null,
                  borderRadius: node.style.roundedCorners
                      ? BorderRadius.circular(6 * zoom)
                      : null,
                ),
                child: Text.rich(
                  nodeSpans[node.name]!,
                  textAlign: TextAlign.center,
                  softWrap: false,
                ),
              ),
            ),
          for (final label in layout.labels)
            Positioned.fromRect(
              rect: label.rect,
              child: Container(
                alignment: Alignment.center,
                // TikZ edge labels conventionally get a halo (fill=white in
                // light mode, matching the paper) so they stay legible where
                // they cross the line — e.g. an [above] label on a vertical
                // edge.
                color: _palette.labelHalo,
                child: Text.rich(
                  labelSpans[label.label]!,
                  textAlign: TextAlign.center,
                  softWrap: false,
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label:
          'TikZ diagram: ${diagram.nodes.length} nodes, '
          '${diagram.edges.length} edges',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          if (!available.isFinite || natural.width <= available) {
            return Center(child: diagramBody);
          }
          final scale = available / natural.width;
          if (scale >= 0.55) {
            return Center(
              child: SizedBox(
                width: available,
                height: natural.height * scale,
                child: FittedBox(fit: BoxFit.contain, child: diagramBody),
              ),
            );
          }
          // Below 55% the labels stop being legible: keep that scale and
          // let the rest scroll horizontally, like wide tables.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: natural.width * 0.55,
              height: natural.height * 0.55,
              child: FittedBox(fit: BoxFit.contain, child: diagramBody),
            ),
          );
        },
      ),
    );
  }
}

final class _TikzEdgePainter extends CustomPainter {
  const _TikzEdgePainter({
    required this.edges,
    required this.ink,
    required this.zoom,
  });

  final List<TikzEdgeSegment> edges;
  final Color ink;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final direction = edge.end - edge.start;
      if (direction.distance == 0) continue;
      final unit = direction / direction.distance;
      final stroke = Paint()
        ..color = ink
        ..strokeWidth = (edge.thick ? 2.0 : 1.3) * zoom
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (edge.arrow) {
        final arrowLength = 8.0 * zoom;
        final halfWidth = 3.4 * zoom;
        final base = edge.end - unit * arrowLength;
        final perpendicular = Offset(-unit.dy, unit.dx) * halfWidth;
        // Stop the shaft inside the head so it never pokes past the tip.
        canvas.drawLine(
          edge.start,
          edge.end - unit * (arrowLength / 2),
          stroke,
        );
        final head = Path()
          ..moveTo(edge.end.dx, edge.end.dy)
          ..lineTo(base.dx + perpendicular.dx, base.dy + perpendicular.dy)
          ..lineTo(base.dx - perpendicular.dx, base.dy - perpendicular.dy)
          ..close();
        canvas.drawPath(head, Paint()..color = ink);
      } else {
        canvas.drawLine(edge.start, edge.end, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_TikzEdgePainter oldDelegate) =>
      edges != oldDelegate.edges ||
      ink != oldDelegate.ink ||
      zoom != oldDelegate.zoom;
}
