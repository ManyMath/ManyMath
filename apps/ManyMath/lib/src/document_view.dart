import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';
import 'package:ratex_flutter/ratex_flutter.dart';

import 'latex_document.dart';
import 'tikz_diagram.dart';

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
            final centeredHorizontalPadding = math.max(
              canvasPadding.left,
              (constraints.maxWidth - 760) / 2,
            );
            final textStyle = TextStyle(
              color: const Color(0xFF18201C),
              fontSize: _bodySize,
              height: 1.55,
              fontFamily: 'Georgia',
              fontFamilyFallback: const <String>[
                'Times New Roman',
                'Noto Serif',
                'serif',
              ],
            );
            return CustomScrollView(
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
                    sliver: SliverPadding(
                      padding: EdgeInsets.all(paperPadding),
                      sliver: blocks.isEmpty
                          ? SliverToBoxAdapter(
                              child: DefaultTextStyle(
                                style: textStyle,
                                child: const Text(
                                  'No rendered content',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF64716B)),
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

  Widget _diagramPlaceholder(String kind) {
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
          'Diagram ($kind) — not rendered',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF64716B),
            fontStyle: FontStyle.italic,
            fontSize: _bodySize * 0.9,
          ),
        ),
      ),
    );
  }

  static const _tikzInk = Color(0xFF18201C);

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
        fontFamily: monospace ? 'ui-monospace' : null,
        color: _tikzInk,
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

    final resolved = resolveTikzLayout(diagram, (node) {
      final size = _measureSpan(nodeSpans[node.name]!);
      return (width: size.width / pxPerCm, height: size.height / pxPerCm);
    });
    // The parser rejects unresolvable placements, so this cannot fail; keep
    // the placeholder as a defensive fallback rather than throwing.
    if (resolved == null) return _diagramPlaceholder('tikzpicture');

    // TikZ y points up; Flutter y points down. Flip while converting to px.
    Rect rectOf(TikzPlacedNode placed) => Rect.fromCenter(
      center: Offset(
        (placed.centerX - resolved.minX) * pxPerCm,
        (resolved.maxY - placed.centerY) * pxPerCm,
      ),
      width: placed.widthCm * pxPerCm,
      height: placed.heightCm * pxPerCm,
    );

    final nodeRects = <String, Rect>{
      for (final entry in resolved.placed.entries)
        entry.key: rectOf(entry.value),
    };

    // The straight center-to-center line, clipped at each node's border.
    Offset borderPoint(Rect rect, Offset direction) {
      final tx = direction.dx == 0
          ? double.infinity
          : (rect.width / 2) / direction.dx.abs();
      final ty = direction.dy == 0
          ? double.infinity
          : (rect.height / 2) / direction.dy.abs();
      return rect.center + direction * math.min(tx, ty);
    }

    final edges = <_TikzEdgeGeometry>[];
    final edgeLabels = <({Rect rect, TextSpan span})>[];
    for (final edge in diagram.edges) {
      final fromRect = nodeRects[edge.from]!;
      final toRect = nodeRects[edge.to]!;
      final direction = toRect.center - fromRect.center;
      if (direction.distance == 0) continue;
      final unit = direction / direction.distance;
      final start = borderPoint(fromRect, unit);
      final end = borderPoint(toRect, -unit);
      edges.add(
        _TikzEdgeGeometry(
          start: start,
          end: end,
          arrow: edge.arrow,
          thick: edge.thick,
        ),
      );
      final label = edge.label;
      if (label == null) continue;
      final span = _tikzLabelSpan(context, label.lines, edgeFontSize);
      final size = _measureSpan(span);
      final gap = 4.0 * zoom;

      // TikZ anchors the label at the path midpoint, offset to the given
      // side. Real pictures put wide labels on short edges, so taking that
      // literally runs labels into nodes; when it does, slide the anchor
      // along the edge, then try riding perpendicular to it, and keep the
      // first spot clear of every node and already-placed label.
      Rect rectAt(Offset anchor) => switch (label.side) {
        TikzSide.above => Rect.fromLTWH(
          anchor.dx - size.width / 2,
          anchor.dy - gap - size.height,
          size.width,
          size.height,
        ),
        TikzSide.below => Rect.fromLTWH(
          anchor.dx - size.width / 2,
          anchor.dy + gap,
          size.width,
          size.height,
        ),
        TikzSide.left => Rect.fromLTWH(
          anchor.dx - gap - size.width,
          anchor.dy - size.height / 2,
          size.width,
          size.height,
        ),
        TikzSide.right => Rect.fromLTWH(
          anchor.dx + gap,
          anchor.dy - size.height / 2,
          size.width,
          size.height,
        ),
      };
      final mid = (start + end) / 2;
      final length = (end - start).distance;
      final normal = Offset(-unit.dy, unit.dx);
      const slides = [0.0, .08, -.08, .16, -.16, .24, -.24, .32, -.32];
      final candidates = <Rect>[
        for (final t in slides) rectAt(mid + unit * (t * length)),
        for (final t in slides)
          for (final direction in [normal, -normal])
            Rect.fromCenter(
              center:
                  mid +
                  unit * (t * length) +
                  direction *
                      (direction.dx.abs() * size.width / 2 +
                          direction.dy.abs() * size.height / 2 +
                          gap),
              width: size.width,
              height: size.height,
            ),
      ];
      bool isClear(Rect rect) {
        final probe = rect.deflate(1);
        for (final nodeRect in nodeRects.values) {
          if (probe.overlaps(nodeRect)) return false;
        }
        for (final other in edgeLabels) {
          if (probe.overlaps(other.rect)) return false;
        }
        return true;
      }

      final rect = candidates.firstWhere(isClear, orElse: () => candidates[0]);
      edgeLabels.add((rect: rect, span: span));
    }

    // Edge labels can stick out past the node bounding box; pad the canvas
    // to whatever the drawing actually covers.
    var bounds = nodeRects.values.reduce((a, b) => a.expandToInclude(b));
    for (final label in edgeLabels) {
      bounds = bounds.expandToInclude(label.rect);
    }
    final margin = 4.0 * zoom;
    final shift = Offset(margin - bounds.left, margin - bounds.top);
    final natural = Size(bounds.width + 2 * margin, bounds.height + 2 * margin);

    final diagramBody = SizedBox(
      width: natural.width,
      height: natural.height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _TikzEdgePainter(
                edges: [for (final e in edges) e.shifted(shift)],
                ink: _tikzInk,
                zoom: zoom,
              ),
            ),
          ),
          for (final node in diagram.nodes)
            Positioned.fromRect(
              rect: nodeRects[node.name]!.shift(shift),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  border: node.style.draw
                      ? Border.all(color: _tikzInk, width: 1.1 * zoom)
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
          for (final label in edgeLabels)
            Positioned.fromRect(
              rect: label.rect.shift(shift),
              child: Container(
                alignment: Alignment.center,
                // TikZ edge labels conventionally get a white halo
                // (fill=white) so they stay legible where they cross the
                // line — e.g. an [above] label on a vertical edge.
                color: const Color(0xE6FFFFFF),
                child: Text.rich(
                  label.span,
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

final class _TikzEdgeGeometry {
  const _TikzEdgeGeometry({
    required this.start,
    required this.end,
    required this.arrow,
    required this.thick,
  });

  final Offset start;
  final Offset end;
  final bool arrow;
  final bool thick;

  _TikzEdgeGeometry shifted(Offset by) => _TikzEdgeGeometry(
    start: start + by,
    end: end + by,
    arrow: arrow,
    thick: thick,
  );
}

final class _TikzEdgePainter extends CustomPainter {
  const _TikzEdgePainter({
    required this.edges,
    required this.ink,
    required this.zoom,
  });

  final List<_TikzEdgeGeometry> edges;
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
