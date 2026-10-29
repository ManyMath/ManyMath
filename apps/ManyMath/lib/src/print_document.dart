import 'package:flutter/widgets.dart';
import 'package:ratex_dart/ratex_dart.dart';

import 'latex_document.dart';
import 'page_setup.dart';
import 'tikz_diagram.dart';

/// Printing goes through a standalone HTML document: the parsed blocks map
/// to semantic HTML, every formula is pre-rendered to a self-contained SVG
/// by the RaTeX engine, and CSS Paged Media (`@page`) hands pagination to
/// the browser — which is also the user's "Save to PDF" path. The output is
/// always black ink on white paper regardless of the on-screen theme: a
/// printed/exported document uses the default light appearance.

/// Stable lookup key for one rendered formula; inline and display variants
/// of the same source are distinct renders.
String formulaKey(String latex, bool displayMode) =>
    '${displayMode ? 'D' : 'I'}:$latex';

/// Renders every formula in [blocks] (plus the macro preamble, so paper
/// macros resolve) to an embed-ready SVG, deduplicated and keyed by
/// [formulaKey]. A formula that fails to render is left out; the HTML
/// builder falls back to showing its source in a code style.
Future<Map<String, String>> renderFormulaSvgs(
  List<DocBlock> blocks,
  String macroPreamble,
) async {
  final wanted = <String, ({String latex, bool displayMode})>{};

  void wantInline(List<DocInline> spans) {
    for (final span in spans) {
      if (span is InlineMath) {
        wanted[formulaKey(span.latex, false)] = (
          latex: span.latex,
          displayMode: false,
        );
      }
    }
  }

  void walk(List<DocBlock> blocks) {
    for (final block in blocks) {
      switch (block) {
        case TitleBlock():
          block.metadataInlines.forEach(wantInline);
        case HeadingBlock():
          wantInline(block.spans);
        case ParagraphBlock():
          wantInline(block.spans);
        case DisplayMathBlock():
          wanted[formulaKey(block.latex, true)] = (
            latex: block.latex,
            displayMode: true,
          );
        case ListBlock():
          for (final item in block.items) {
            walk(item);
          }
        case BibliographyBlock():
          for (final entry in block.entries) {
            wantInline(entry.spans);
          }
        case TableBlock():
          for (final row in block.rows) {
            for (final cell in row) {
              wantInline(cell.spans);
            }
          }
        case CenterBlock():
          walk(block.children);
        case FramedBlock():
          walk(block.children);
        case QuoteBlock():
          walk(block.children);
        case TheoremBlock():
          if (block.title != null) wantInline(block.title!);
          walk(block.body);
        case CaptionBlock():
          wantInline(block.spans);
        case FootnoteBlock():
          wantInline(block.spans);
        case TikzDiagramBlock():
          for (final line in block.diagram.allLabelLines) {
            wantInline(parseInline(line));
          }
        case CodeBlock():
        case DiagramBlock():
          break;
      }
    }
  }

  walk(blocks);

  final svgs = <String, String>{};
  for (final entry in wanted.entries) {
    try {
      svgs[entry.key] = await Ratex.renderSvg(
        macroPreamble + entry.value.latex,
        options: RatexOptions(
          displayMode: entry.value.displayMode,
          fontSize: entry.value.displayMode ? 20 : 16,
          padding: 2,
          color: '#18201C',
        ),
      );
    } catch (_) {
      // Leave the key absent; the builder substitutes a code fallback.
    }
  }
  return svgs;
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Builds the standalone print document. [fontBaseUrl] points at the
/// directory holding the app's bundled fonts (so the print window renders
/// the same faces as the preview); [formulaSvgs] comes from
/// [renderFormulaSvgs].
String buildPrintHtml({
  required String title,
  required List<DocBlock> blocks,
  required PageSize pageSize,
  required Map<String, String> formulaSvgs,
  required String fontBaseUrl,
}) {
  final body = StringBuffer();
  for (final block in blocks) {
    _blockHtml(body, block, formulaSvgs);
  }

  return '<!DOCTYPE html>\n'
      '<html lang="en">\n'
      '<head>\n'
      '<meta charset="utf-8">\n'
      '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
      '<title>${_escape(title)}</title>\n'
      '<style>\n'
      '@font-face { font-family: "Latin Modern Roman"; '
      'src: url("${fontBaseUrl}lmroman10-regular.otf"); }\n'
      '@font-face { font-family: "Latin Modern Roman"; font-weight: bold; '
      'src: url("${fontBaseUrl}lmroman10-bold.otf"); }\n'
      '@font-face { font-family: "Latin Modern Roman"; font-style: italic; '
      'src: url("${fontBaseUrl}lmroman10-italic.otf"); }\n'
      '@font-face { font-family: "Latin Modern Roman"; font-weight: bold; '
      'font-style: italic; '
      'src: url("${fontBaseUrl}lmroman10-bolditalic.otf"); }\n'
      '@font-face { font-family: "JetBrains Mono"; '
      'src: url("${fontBaseUrl}jetbrains-mono-var.ttf"); }\n'
      '@page { size: ${pageSize.cssName}; margin: 0.75in; }\n'
      'html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }\n'
      'body { font-family: "Latin Modern Roman", Georgia, "Times New Roman", '
      'serif; font-size: 12pt; line-height: 1.55; color: #18201C; '
      'background: #FFFFFF; margin: 0; }\n'
      'code, pre { font-family: "JetBrains Mono", ui-monospace, Menlo, '
      'Consolas, monospace; font-size: 0.88em; }\n'
      'pre { background: #F5F7F6; border: 1px solid #D9DEDC; '
      'border-radius: 4px; padding: 8pt 10pt; overflow-x: auto; '
      'white-space: pre-wrap; }\n'
      '.title { text-align: center; font-size: 20pt; line-height: 1.25; '
      'margin: 0 0 6pt; }\n'
      '.author, .date { text-align: center; margin: 2pt 0; }\n'
      '.date { font-style: italic; }\n'
      'h1 { font-size: 17pt; margin: 16pt 0 6pt; }\n'
      'h2 { font-size: 14.5pt; margin: 14pt 0 5pt; }\n'
      'h3 { font-size: 12.5pt; margin: 12pt 0 4pt; }\n'
      'p { margin: 0 0 9pt; }\n'
      '.formula-display { text-align: center; margin: 10pt 0; '
      'overflow-x: auto; }\n'
      '.formula-display svg { max-width: 100%; }\n'
      'svg { vertical-align: middle; }\n'
      'ul, ol { margin: 0 0 9pt; padding-left: 22pt; }\n'
      'li { margin: 0 0 3pt; }\n'
      'ul.desc { list-style: none; padding-left: 10pt; }\n'
      'blockquote { border-left: 2.5pt solid #D9DEDC; margin: 6pt 0; '
      'padding: 1pt 0 1pt 12pt; }\n'
      '.framed { border: 1px solid #8A918D; padding: 8pt 10pt; '
      'margin: 6pt 0; }\n'
      '.center { text-align: center; }\n'
      '.theorem { background: #F5F7F6; border: 1px solid #D9DEDC; '
      'border-radius: 4px; padding: 8pt 10pt; margin: 6pt 0; }\n'
      '.theorem.proof { background: none; border: none; padding: 0; }\n'
      '.caption { text-align: center; font-size: 0.9em; margin: 3pt 0 8pt; }\n'
      '.footnote { font-size: 0.85em; margin: 1.5pt 0; }\n'
      '.biblio p { margin: 0 0 4pt; padding-left: 24pt; '
      'text-indent: -24pt; }\n'
      'table { border-collapse: collapse; margin: 6pt 0; }\n'
      'td, th { border: 1px solid #8A918D; padding: 3pt 7pt; }\n'
      '.diagram-note { font-style: italic; color: #4A5450; '
      'text-align: center; }\n'
      '.tikz { margin: 10pt 0; text-align: center; break-inside: avoid; }\n'
      '.tikz svg { max-width: 100%; height: auto; overflow: visible; }\n'
      '.tikz-text { width: 100%; height: 100%; display: flex; '
      'flex-direction: column; align-items: center; justify-content: center; '
      'line-height: 1.3; white-space: nowrap; text-align: center; }\n'
      '.tikz-text.mono { font-family: "JetBrains Mono", ui-monospace, Menlo, '
      'Consolas, monospace; }\n'
      '.tikz-text code { font-size: 1em; }\n'
      '.tikz-text.halo { background: #FFFFFF; }\n'
      '.toolbar { position: sticky; top: 0; display: flex; gap: 8px; '
      'align-items: center; background: #18201C; color: #FFFFFF; '
      'padding: 8px 12px; font-family: system-ui, sans-serif; '
      'font-size: 13px; }\n'
      '.toolbar button { font: inherit; padding: 4px 14px; cursor: pointer; }\n'
      '@media print { .toolbar { display: none; } }\n'
      '</style>\n'
      '</head>\n'
      '<body>\n'
      '<div class="toolbar">\n'
      '<button id="manymath-print" type="button">Print</button>\n'
      '<span>${_escape(title)} — ${pageSize.label}. '
      'Use the browser dialog to save as PDF.</span>\n'
      '</div>\n'
      '${blocks.isEmpty ? '<p class="diagram-note">No rendered content</p>' : body.toString()}'
      '</body>\n'
      '</html>\n';
}

void _blockHtml(
  StringBuffer out,
  DocBlock block,
  Map<String, String> formulaSvgs,
) {
  switch (block) {
    case TitleBlock():
      if (block.titleInlines case final title?) {
        out.write('<h1 class="title">${_inlineHtml(title, formulaSvgs)}</h1>');
      }
      if (block.authorInlines case final author?) {
        out.write('<p class="author">${_inlineHtml(author, formulaSvgs)}</p>');
      }
      if (block.dateInlines case final date?) {
        out.write('<p class="date">${_inlineHtml(date, formulaSvgs)}</p>');
      }
    case HeadingBlock():
      final tag = switch (block.level) {
        1 => 'h1',
        2 => 'h2',
        _ => 'h3',
      };
      out.write('<$tag>${_inlineHtml(block.spans, formulaSvgs)}</$tag>');
    case ParagraphBlock():
      out.write('<p>${_inlineHtml(block.spans, formulaSvgs)}</p>');
    case DisplayMathBlock():
      final svg = formulaSvgs[formulaKey(block.latex, true)];
      out.write(
        svg != null
            ? '<div class="formula-display">$svg</div>'
            : '<pre>${_escape(block.latex)}</pre>',
      );
    case ListBlock():
      final items = StringBuffer();
      for (final item in block.items) {
        items.write('<li>');
        for (final child in item) {
          _blockHtml(items, child, formulaSvgs);
        }
        items.write('</li>');
      }
      out.write(switch (block.style) {
        ListStyle.numbered => '<ol>$items</ol>',
        ListStyle.bullet => '<ul>$items</ul>',
        ListStyle.description => '<ul class="desc">$items</ul>',
      });
    case CodeBlock():
      out.write('<pre>${_escape(block.code)}</pre>');
    case BibliographyBlock():
      out.write('<div class="biblio">');
      for (final entry in block.entries) {
        out.write(
          '<p>[${entry.number}]&nbsp; ${_inlineHtml(entry.spans, formulaSvgs)}</p>',
        );
      }
      out.write('</div>');
    case QuoteBlock():
      out.write('<blockquote>');
      for (final child in block.children) {
        _blockHtml(out, child, formulaSvgs);
      }
      out.write('</blockquote>');
    case TheoremBlock():
      final isProof = block.noun == 'Proof';
      final name = _escape(
        block.number == null ? block.noun : '${block.noun} ${block.number}',
      );
      final title = block.title == null
          ? null
          : _inlineHtml(block.title!, formulaSvgs);
      out.write('<div class="theorem${isProof ? ' proof' : ''}">');
      // amsthm: "Theorem 1 (Title)." with the note upright, and a proof's
      // optional title replaces the word "Proof".
      out.write(switch ((isProof, title)) {
        (true, null) => '<p><em>Proof.</em> ',
        (true, final title?) => '<p><em>$title.</em> ',
        (false, null) => '<p><strong>$name.</strong> ',
        (false, final title?) =>
          '<p><strong>$name</strong> ($title)<strong>.</strong> ',
      });
      // The label runs into the first paragraph; any other first child
      // closes the label's paragraph before it.
      var first = true;
      for (final child in block.body) {
        if (first && child is ParagraphBlock) {
          out.write(_inlineHtml(child.spans, formulaSvgs));
          out.write('</p>');
        } else {
          if (first) out.write('</p>');
          _blockHtml(out, child, formulaSvgs);
        }
        first = false;
      }
      if (block.body.isEmpty) out.write('</p>');
      if (isProof) out.write('<p style="text-align:right">∎</p>');
      out.write('</div>');
    case TableBlock():
      out.write('<table>');
      for (final row in block.rows) {
        out.write('<tr>');
        for (final cell in row) {
          out.write(
            '<td${cell.colSpan > 1 ? ' colspan="${cell.colSpan}"' : ''}>'
            '${_inlineHtml(cell.spans, formulaSvgs)}</td>',
          );
        }
        out.write('</tr>');
      }
      out.write('</table>');
    case CenterBlock():
      out.write('<div class="center">');
      for (final child in block.children) {
        _blockHtml(out, child, formulaSvgs);
      }
      out.write('</div>');
    case FramedBlock():
      out.write('<div class="framed">');
      for (final child in block.children) {
        _blockHtml(out, child, formulaSvgs);
      }
      out.write('</div>');
    case CaptionBlock():
      out.write(
        '<p class="caption"><strong>${_escape(block.label)}: </strong>'
        '${_inlineHtml(block.spans, formulaSvgs)}</p>',
      );
    case FootnoteBlock():
      out.write(
        '<p class="footnote">${block.number}. '
        '${_inlineHtml(block.spans, formulaSvgs)}</p>',
      );
    case DiagramBlock():
      out.write(
        '<p class="diagram-note">(Diagram omitted from print; '
        'see the on-screen preview.)</p>',
      );
    case TikzDiagramBlock():
      out.write(
        _tikzHtml(block.diagram, formulaSvgs) ??
            '<p class="diagram-note">(TikZ diagram omitted from print; '
                'see the on-screen preview.)</p>',
      );
  }
}

/// Print geometry for TikZ: true centimetres at 96 CSS px per inch, with
/// text, strokes and arrowheads in the same proportion to a centimetre as
/// the on-screen preview at 100% zoom (12px node text at 35px per cm).
const double _tikzPxPerCm = 96 / 2.54;
const double _tikzScale = _tikzPxPerCm / 35;
const double _tikzNodeFontPx = 12 * _tikzScale;
const double _tikzEdgeFontPx = 10.5 * _tikzScale;
const String _ink = '#18201C';

/// One diagram as a single scalable SVG: edges and node boxes as shapes,
/// every label an HTML box in a foreignObject so it keeps inline formula
/// SVGs and scales down with the drawing when it is wider than the page.
/// Null when the layout cannot be resolved.
String? _tikzHtml(TikzDiagram diagram, Map<String, String> formulaSvgs) {
  final layout = layoutTikzDiagram(
    diagram,
    pxPerCm: _tikzPxPerCm,
    measureNode: (node) => _measureLabel(
      node.labelLines,
      _tikzNodeFontPx,
      formulaSvgs,
      monospace: node.style.monospace,
    ),
    measureEdgeLabel: (label) =>
        _measureLabel(label.lines, _tikzEdgeFontPx, formulaSvgs),
    labelGap: 4 * _tikzScale,
    margin: 4 * _tikzScale,
  );
  if (layout == null) return null;
  String n(double value) => value.toStringAsFixed(2);
  String labelBox(
    Rect rect,
    List<String> lines,
    double fontPx, {
    bool monospace = false,
    bool halo = false,
  }) {
    final text = [
      for (final line in lines)
        _inlineHtml(parseInline(line, monospace: monospace), formulaSvgs),
    ].join('<br>');
    final classes = [
      'tikz-text',
      if (monospace) 'mono',
      if (halo) 'halo',
    ].join(' ');
    return '<foreignObject x="${n(rect.left)}" y="${n(rect.top)}" '
        'width="${n(rect.width)}" height="${n(rect.height)}">'
        '<div class="$classes" style="font-size: ${n(fontPx)}px">$text</div>'
        '</foreignObject>';
  }

  final width = layout.size.width;
  final height = layout.size.height;
  final out = StringBuffer(
    '<figure class="tikz">'
    '<svg role="img" aria-label="TikZ diagram: ${diagram.nodes.length} '
    'nodes, ${diagram.edges.length} edges" '
    'viewBox="0 0 ${n(width)} ${n(height)}" width="${n(width)}" '
    'height="${n(height)}">',
  );
  for (final edge in layout.edges) {
    final stroke = (edge.thick ? 2.0 : 1.3) * _tikzScale;
    final direction = edge.end - edge.start;
    final unit = direction / direction.distance;
    final arrowLength = 8 * _tikzScale;
    // Stop the shaft inside the head so it never pokes past the tip.
    final shaftEnd = edge.arrow
        ? edge.end - unit * (arrowLength / 2)
        : edge.end;
    out.write(
      '<line x1="${n(edge.start.dx)}" y1="${n(edge.start.dy)}" '
      'x2="${n(shaftEnd.dx)}" y2="${n(shaftEnd.dy)}" stroke="$_ink" '
      'stroke-width="${n(stroke)}" stroke-linecap="round"/>',
    );
    if (edge.arrow) {
      final base = edge.end - unit * arrowLength;
      final side = Offset(-unit.dy, unit.dx) * (3.4 * _tikzScale);
      final left = base + side;
      final right = base - side;
      out.write(
        '<polygon points="${n(edge.end.dx)},${n(edge.end.dy)} '
        '${n(left.dx)},${n(left.dy)} ${n(right.dx)},${n(right.dy)}" '
        'fill="$_ink"/>',
      );
    }
  }
  for (final node in diagram.nodes) {
    final rect = layout.nodes[node.name]!;
    out.write(
      '<rect x="${n(rect.left)}" y="${n(rect.top)}" '
      'width="${n(rect.width)}" height="${n(rect.height)}" '
      '${node.style.roundedCorners ? 'rx="${n(6 * _tikzScale)}" ' : ''}'
      'fill="#FFFFFF"'
      '${node.style.draw ? ' stroke="$_ink" stroke-width="${n(1.1 * _tikzScale)}"' : ''}'
      '/>',
    );
    out.write(
      labelBox(
        rect,
        node.labelLines,
        _tikzNodeFontPx,
        monospace: node.style.monospace,
      ),
    );
  }
  for (final label in layout.labels) {
    out.write(
      labelBox(label.rect, label.label.lines, _tikzEdgeFontPx, halo: true),
    );
  }
  out.write('</svg></figure>');
  return out.toString();
}

/// A label's size as the print window will set it, measured with the same
/// faces it loads. Formulas count at the size of their rendered SVG.
Size _measureLabel(
  List<String> lines,
  double fontPx,
  Map<String, String> formulaSvgs, {
  bool monospace = false,
}) {
  final placeholders = <PlaceholderDimensions>[];
  final children = <InlineSpan>[];
  for (final (index, line) in lines.indexed) {
    if (index > 0) children.add(const TextSpan(text: '\n'));
    for (final span in parseInline(line, monospace: monospace)) {
      switch (span) {
        case TextRun():
          children.add(
            TextSpan(
              text: span.text,
              style: TextStyle(
                fontWeight: span.bold ? FontWeight.w700 : null,
                fontStyle: span.italic ? FontStyle.italic : null,
                fontFamily: span.monospace ? 'JetBrains Mono' : null,
              ),
            ),
          );
        case InlineMath():
          final size = _svgSize(formulaSvgs[formulaKey(span.latex, false)]);
          placeholders.add(
            PlaceholderDimensions(
              size: size ?? Size(fontPx, fontPx),
              alignment: PlaceholderAlignment.middle,
            ),
          );
          // TextPainter sizes the placeholder from the dimensions above.
          children.add(
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox.shrink(),
            ),
          );
      }
    }
  }
  final painter = TextPainter(
    text: TextSpan(
      children: children,
      style: TextStyle(
        fontSize: fontPx,
        height: 1.3,
        fontFamily: monospace ? 'JetBrains Mono' : 'Latin Modern Roman',
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  );
  if (placeholders.isNotEmpty) {
    painter.setPlaceholderDimensions(placeholders);
  }
  painter.layout();
  final size = Size(
    painter.width.ceilToDouble(),
    painter.height.ceilToDouble(),
  );
  painter.dispose();
  return size;
}

/// The CSS pixel size a RaTeX SVG declares (`width="…pt"`), if any.
Size? _svgSize(String? svg) {
  if (svg == null) return null;
  final width = RegExp(r'width="([\d.]+)pt"').firstMatch(svg);
  final height = RegExp(r'height="([\d.]+)pt"').firstMatch(svg);
  final w = double.tryParse(width?.group(1) ?? '');
  final h = double.tryParse(height?.group(1) ?? '');
  if (w == null || h == null) return null;
  return Size(w * 96 / 72, h * 96 / 72);
}

String _inlineHtml(List<DocInline> spans, Map<String, String> formulaSvgs) {
  final out = StringBuffer();
  for (final span in spans) {
    switch (span) {
      case TextRun():
        var text = _escape(span.text);
        if (span.monospace) text = '<code>$text</code>';
        if (span.bold) text = '<strong>$text</strong>';
        if (span.italic) text = '<em>$text</em>';
        if (span.underline) text = '<u>$text</u>';
        out.write(text);
      case InlineMath():
        final svg = formulaSvgs[formulaKey(span.latex, false)];
        out.write(svg ?? '<code>${_escape(span.latex)}</code>');
    }
  }
  return out.toString();
}
