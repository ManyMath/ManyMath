import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';
import 'package:ratex_flutter/ratex_flutter.dart';

import 'latex_document.dart';

class DocumentView extends StatelessWidget {
  const DocumentView({
    required this.blocks,
    this.macroPreamble = '',
    this.zoom = 1,
    super.key,
  });

  final List<DocBlock> blocks;

  /// `\providecommand`/`\def` statements collected from the whole document
  /// (see `extractMacroPreamble`), prepended to every formula so RaTeX's
  /// macro expander can resolve the paper's own macros.
  final String macroPreamble;
  final double zoom;

  double get _bodySize => 16 * zoom;

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
            final paperPadding = compact ? 24.0 : 48.0;
            return ListView(
              padding: canvasPadding,
              children: <Widget>[
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 760),
                    padding: EdgeInsets.all(paperPadding),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFFD9DEDB)),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: const Color(0xFF18201C),
                        fontSize: _bodySize,
                        height: 1.55,
                        fontFamily: 'Georgia',
                        fontFamilyFallback: const <String>[
                          'Times New Roman',
                          'Noto Serif',
                          'serif',
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (blocks.isEmpty)
                            Text(
                              'No rendered content',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: const Color(0xFF64716B)),
                            ),
                          for (final block in blocks)
                            _buildBlock(context, block),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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
      color: const Color(0xFF18201C),
      semanticLabel: 'Math formula: $latex',
      loadingBuilder: (_) => SizedBox(height: fontSize),
      errorBuilder: (_, error) => Text(
        'Formula error: ${error.message}',
        style: TextStyle(
          color: MTheme.of(context).colors.destructive,
          fontFamily: 'ui-monospace',
          fontSize: fontSize * 0.68,
        ),
      ),
    );
  }

  Widget _buildBlock(BuildContext context, DocBlock block) {
    switch (block) {
      case TitleBlock():
        Widget metadata(
          String source,
          List<int>? sourceMap,
          double fontSize,
          TextStyle style,
        ) {
          return Text.rich(
            TextSpan(
              children: _inlineSpans(
                context,
                parseInline(source, sourceMap: sourceMap),
                fontSize,
              ),
            ),
            textAlign: TextAlign.center,
            style: style,
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 24 * zoom),
          child: Column(
            children: <Widget>[
              if (block.title != null)
                Semantics(
                  header: true,
                  headingLevel: 2,
                  child: metadata(
                    block.title!,
                    block.titleSourceMap,
                    28 * zoom,
                    TextStyle(
                      fontSize: 28 * zoom,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (block.author != null)
                Padding(
                  padding: EdgeInsets.only(top: 8 * zoom),
                  child: metadata(
                    block.author!,
                    block.authorSourceMap,
                    _bodySize,
                    TextStyle(fontSize: _bodySize),
                  ),
                ),
              if (block.date != null)
                Padding(
                  padding: EdgeInsets.only(top: 4 * zoom),
                  child: metadata(
                    block.date!,
                    block.dateSourceMap,
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
              color: const Color(0xFFF2F4F3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFD9DEDB)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                block.code,
                style: TextStyle(
                  fontFamily: 'ui-monospace',
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
              border: TableBorder.all(color: const Color(0xFFD9DEDB)),
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
              border: Border.all(color: const Color(0xFF8A948E)),
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
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8 * zoom),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16 * zoom),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFD9DEDB)),
            ),
            child: Text(
              'Diagram (${block.kind}) — not rendered',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF64716B),
                fontStyle: FontStyle.italic,
                fontSize: _bodySize * 0.9,
              ),
            ),
          ),
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
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFFD9DEDB), width: 3),
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
                  TextSpan(
                    text: block.number == null
                        ? '${block.noun}. '
                        : '${block.noun} ${block.number}. ',
                    style: TextStyle(
                      fontWeight: isProof ? null : FontWeight.w700,
                      fontStyle: isProof ? FontStyle.italic : null,
                    ),
                  ),
                  if (block.title != null) ...[
                    TextSpan(
                      children: _inlineSpans(context, block.title!, _bodySize),
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const TextSpan(text: '. '),
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
                    color: const Color(0xFFF7F5F0),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE3DDCE)),
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
              fontFamily: span.monospace ? 'ui-monospace' : null,
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
}
