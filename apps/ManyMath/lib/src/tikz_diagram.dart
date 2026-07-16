/// A deliberately small TikZ *diagram* interpreter, in the same spirit as
/// `latex_document.dart`: pure Dart, no engine, understands exactly the
/// subset the bundled papers draw with — rectangular `\node`s at absolute
/// coordinates or `positioning`-library relative placement, and straight
/// `\draw (a) -- (b)` edges with optional arrowheads and midpoint labels.
///
/// [parseTikzDiagram] returns null for anything outside that subset, so the
/// caller can keep its generic "not rendered" placeholder: the interpreter
/// never guesses at pictures it cannot draw faithfully, and never leaks raw
/// TikZ source.
///
/// Positions use TikZ conventions: centimetres, y axis pointing *up*.
/// [resolveTikzLayout] turns relative placements into concrete node rects;
/// it takes a label-measuring callback because node extents depend on label
/// text size, which only the renderer knows.
library;

/// Placement side, for both `positioning` keys (`right=3cm of x`) and edge
/// label anchors (`node[above] {...}`).
enum TikzSide { above, below, left, right }

/// Where a node goes: `at (x, y)` (also the implicit origin default).
sealed class TikzPlacement {
  const TikzPlacement();
}

final class TikzAbsolute extends TikzPlacement {
  const TikzAbsolute(this.x, this.y);

  final double x;
  final double y;
}

/// `positioning`-library placement: this node's border sits [gapCm] from
/// the facing border of [ref] (TikZ's `right=3cm of ref` semantics).
final class TikzRelative extends TikzPlacement {
  const TikzRelative(this.side, this.gapCm, this.ref);

  final TikzSide side;
  final double gapCm;
  final String ref;
}

final class TikzNodeStyle {
  const TikzNodeStyle({
    this.draw = false,
    this.roundedCorners = false,
    this.minHeightCm = 0,
    this.innerSepCm = _defaultInnerSepCm,
    this.monospace = false,
  });

  final bool draw;
  final bool roundedCorners;
  final double minHeightCm;
  final double innerSepCm;
  final bool monospace;

  TikzNodeStyle copyWith({
    bool? draw,
    bool? roundedCorners,
    double? minHeightCm,
    double? innerSepCm,
    bool? monospace,
  }) {
    return TikzNodeStyle(
      draw: draw ?? this.draw,
      roundedCorners: roundedCorners ?? this.roundedCorners,
      minHeightCm: minHeightCm ?? this.minHeightCm,
      innerSepCm: innerSepCm ?? this.innerSepCm,
      monospace: monospace ?? this.monospace,
    );
  }
}

final class TikzNode {
  const TikzNode({
    required this.name,
    required this.labelLines,
    required this.placement,
    required this.style,
  });

  final String name;

  /// The label split at `\\` line breaks; each line is LaTeX text meant for
  /// the document's inline-span pipeline (so `\_` and ligatures work).
  final List<String> labelLines;
  final TikzPlacement placement;
  final TikzNodeStyle style;
}

final class TikzEdgeLabel {
  const TikzEdgeLabel(this.lines, this.side);

  final List<String> lines;
  final TikzSide side;
}

final class TikzEdge {
  const TikzEdge({
    required this.from,
    required this.to,
    this.arrow = false,
    this.thick = false,
    this.label,
  });

  final String from;
  final String to;
  final bool arrow;
  final bool thick;
  final TikzEdgeLabel? label;
}

final class TikzDiagram {
  const TikzDiagram({required this.nodes, required this.edges, this.scale = 1});

  final List<TikzNode> nodes;
  final List<TikzEdge> edges;
  final double scale;

  /// Every LaTeX text line the diagram will render (node and edge labels),
  /// for tooling that scans documents span-by-span (leak audits, word
  /// counts).
  Iterable<String> get allLabelLines sync* {
    for (final node in nodes) {
      yield* node.labelLines;
    }
    for (final edge in edges) {
      final label = edge.label;
      if (label != null) yield* label.lines;
    }
  }
}

/// TikZ's `inner sep` default is 0.3333em; at 10pt that is ~3.3pt.
const _defaultInnerSepCm = 3.3333 * _cmPerPt;
const _cmPerPt = 2.54 / 72.27;

/// Parses the body of a `tikzpicture` environment (everything between
/// `\begin{tikzpicture}` and `\end{tikzpicture}`, comments already
/// stripped). Returns null when the picture uses anything outside the
/// supported subset.
TikzDiagram? parseTikzDiagram(String code) {
  // One of the bundled papers was machine-converted from Markdown and the
  // conversion left artifacts a real TeX run would also choke on; they are
  // unambiguous, so normalize them instead of failing the whole picture:
  // escaped brackets (`\[` for `[`) and stray ``` fence lines.
  var text = code.replaceAll(r'\[', '[').replaceAll(r'\]', ']');
  text = text
      .split('\n')
      .where((line) => line.trim() != '```')
      .join('\n')
      .trim();

  var scale = 1.0;
  var nodeDistanceCm = 1.0;
  var everyNode = const TikzNodeStyle();
  // Styles introduced by `<name>/.style={...}` in the picture options and
  // referenced from `\draw[<name>]`.
  final edgeStyles = <String, ({bool arrow, bool thick})>{};

  ({TikzNodeStyle? style, TikzPlacement? placement}) parseNodeOptions(
    String options,
    TikzNodeStyle base,
  ) {
    var style = base;
    TikzPlacement? placement;
    for (final option in _splitTopLevel(options, ',')) {
      final opt = option.trim();
      if (opt.isEmpty) continue;
      final eq = _topLevelIndexOf(opt, '=');
      final key = (eq < 0 ? opt : opt.substring(0, eq)).trim();
      final value = eq < 0 ? null : opt.substring(eq + 1).trim();
      switch (key) {
        case 'draw':
          style = style.copyWith(draw: true);
        case 'rectangle':
          break; // The only shape this interpreter draws.
        case 'rounded corners':
          style = style.copyWith(roundedCorners: true);
        case 'align':
          if (value != 'center') return (style: null, placement: null);
        case 'font':
          if (value != r'\ttfamily') return (style: null, placement: null);
          style = style.copyWith(monospace: true);
        case 'minimum height':
          final length = value == null ? null : _parseLengthCm(value);
          if (length == null) return (style: null, placement: null);
          style = style.copyWith(minHeightCm: length);
        case 'inner sep':
          final length = value == null ? null : _parseLengthCm(value);
          if (length == null) return (style: null, placement: null);
          style = style.copyWith(innerSepCm: length);
        case 'above' || 'below' || 'left' || 'right':
          final side = TikzSide.values.byName(key);
          // `right=3cm of x`; a bare `right=of x` uses `node distance`.
          final match = value == null
              ? null
              : RegExp(r'^(?:(\S+)\s+)?of\s+([\w.-]+)$').firstMatch(value);
          if (match == null) return (style: null, placement: null);
          final rawGap = match.group(1);
          final gap = rawGap == null ? nodeDistanceCm : _parseLengthCm(rawGap);
          if (gap == null) return (style: null, placement: null);
          placement = TikzRelative(side, gap, match.group(2)!);
        default:
          return (style: null, placement: null);
      }
    }
    return (style: style, placement: placement);
  }

  ({bool arrow, bool thick})? parseDrawOptions(String options) {
    var arrow = false;
    var thick = false;
    for (final option in _splitTopLevel(options, ',')) {
      final opt = option.trim();
      if (opt.isEmpty) continue;
      if (opt == '->' || opt == '-{Latex}' || opt == '-{Stealth}') {
        arrow = true;
      } else if (opt == '-') {
        arrow = false;
      } else if (opt == 'thick') {
        thick = true;
      } else if (edgeStyles.containsKey(opt)) {
        arrow = arrow || edgeStyles[opt]!.arrow;
        thick = thick || edgeStyles[opt]!.thick;
      } else {
        return null;
      }
    }
    return (arrow: arrow, thick: thick);
  }

  // Picture options: [node distance=1.8cm, auto, >=stealth, scale=1,
  // every node/.style={...}, edge/.style={...}].
  if (text.startsWith('[')) {
    final close = _matchingBracket(text, 0);
    if (close < 0) return null;
    for (final option in _splitTopLevel(text.substring(1, close), ',')) {
      final opt = option.trim();
      if (opt.isEmpty || opt == 'auto') continue;
      if (opt.startsWith('>=')) continue; // Arrow-tip aesthetics.
      final eq = _topLevelIndexOf(opt, '=');
      final key = (eq < 0 ? opt : opt.substring(0, eq)).trim();
      final value = eq < 0 ? null : opt.substring(eq + 1).trim();
      if (key == 'node distance' && value != null) {
        final length = _parseLengthCm(value);
        if (length == null) return null;
        nodeDistanceCm = length;
      } else if (key == 'scale' && value != null) {
        final parsed = double.tryParse(value);
        if (parsed == null || parsed <= 0) return null;
        scale = parsed;
      } else if (key.endsWith('/.style') && value != null) {
        final styleName = key.substring(0, key.length - '/.style'.length);
        var body = value;
        if (body.startsWith('{') && body.endsWith('}')) {
          body = body.substring(1, body.length - 1);
        }
        if (styleName == 'every node') {
          final parsed = parseNodeOptions(body, everyNode);
          if (parsed.style == null || parsed.placement != null) return null;
          everyNode = parsed.style!;
        } else {
          final parsed = parseDrawOptions(body);
          if (parsed == null) return null;
          edgeStyles[styleName] = parsed;
        }
      } else {
        return null;
      }
    }
    text = text.substring(close + 1);
  }

  final nodes = <TikzNode>[];
  final edges = <TikzEdge>[];
  final nodeNames = <String>{};

  for (final rawStatement in _splitTopLevel(text, ';')) {
    final statement = rawStatement.trim();
    if (statement.isEmpty) continue;
    if (statement.startsWith(r'\node')) {
      var rest = statement.substring(r'\node'.length).trim();
      var style = everyNode;
      TikzPlacement? placement;
      if (rest.startsWith('[')) {
        final close = _matchingBracket(rest, 0);
        if (close < 0) return null;
        final parsed = parseNodeOptions(rest.substring(1, close), everyNode);
        if (parsed.style == null) return null;
        style = parsed.style!;
        placement = parsed.placement;
        rest = rest.substring(close + 1).trim();
      }
      final name = RegExp(r'^\(([\w.-]+)\)').firstMatch(rest);
      if (name == null) return null;
      rest = rest.substring(name.end).trim();
      if (rest.startsWith('at')) {
        final at = RegExp(
          r'^at\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)',
        ).firstMatch(rest);
        if (at == null || placement != null) return null;
        placement = TikzAbsolute(
          double.parse(at.group(1)!),
          double.parse(at.group(2)!),
        );
        rest = rest.substring(at.end).trim();
      }
      if (!rest.startsWith('{') || !rest.endsWith('}')) return null;
      if (_matchingBracket(rest, 0) != rest.length - 1) return null;
      final label = _splitLabelLines(rest.substring(1, rest.length - 1));
      if (label == null) return null;
      // Relative placement must refer to an already-declared node, so
      // resolveTikzLayout can place nodes in declaration order.
      if (placement is TikzRelative && !nodeNames.contains(placement.ref)) {
        return null;
      }
      final nodeName = name.group(1)!;
      if (!nodeNames.add(nodeName)) return null;
      nodes.add(
        TikzNode(
          name: nodeName,
          labelLines: label,
          placement: placement ?? const TikzAbsolute(0, 0),
          style: style,
        ),
      );
    } else if (statement.startsWith(r'\draw')) {
      var rest = statement.substring(r'\draw'.length).trim();
      var arrow = false;
      var thick = false;
      if (rest.startsWith('[')) {
        final close = _matchingBracket(rest, 0);
        if (close < 0) return null;
        final parsed = parseDrawOptions(rest.substring(1, close));
        if (parsed == null) return null;
        arrow = parsed.arrow;
        thick = parsed.thick;
        rest = rest.substring(close + 1).trim();
      }
      final path = RegExp(
        r'^\(([\w.-]+)\)\s*--\s*(?:node\s*(?:\[(\w*)\])?\s*(\{.*\})\s*)?\(([\w.-]+)\)$',
        dotAll: true,
      ).firstMatch(rest);
      if (path == null) return null;
      TikzEdgeLabel? label;
      final labelBody = path.group(3);
      if (labelBody != null) {
        if (_matchingBracket(labelBody, 0) != labelBody.length - 1) {
          return null;
        }
        final sideName = path.group(2);
        final side = sideName == null || sideName.isEmpty
            ? TikzSide.above
            : TikzSide.values.asNameMap()[sideName];
        final lines = _splitLabelLines(
          labelBody.substring(1, labelBody.length - 1),
        );
        if (side == null || lines == null) return null;
        label = TikzEdgeLabel(lines, side);
      }
      edges.add(
        TikzEdge(
          from: path.group(1)!,
          to: path.group(4)!,
          arrow: arrow,
          thick: thick,
          label: label,
        ),
      );
    } else {
      return null;
    }
  }

  if (nodes.isEmpty) return null;
  for (final edge in edges) {
    if (!nodeNames.contains(edge.from) || !nodeNames.contains(edge.to)) {
      return null;
    }
  }
  return TikzDiagram(nodes: nodes, edges: edges, scale: scale);
}

/// Splits a `{...}` label body into display lines at `\\`. The Markdown
/// conversion mentioned in [parseTikzDiagram] also collapsed some `\\` line
/// breaks to a single backslash (`STREAM\ChaCha20-...`); a backslash
/// directly before an uppercase letter or digit can only be that artifact
/// (no supported text command starts that way), so it splits too. Returns
/// null when the label uses an unsupported construct (unbalanced braces).
const _backslash = '\\';

List<String>? _splitLabelLines(String body) {
  if (_topLevelIndexOf(body, ' ') == -2) return null; // Unbalanced.
  final lines = <String>[];
  final current = StringBuffer();
  var i = 0;
  while (i < body.length) {
    if (body.startsWith(r'\\', i)) {
      lines.add(current.toString());
      current.clear();
      i += 2;
    } else if (body[i] == _backslash &&
        i + 1 < body.length &&
        RegExp(r'[A-Z0-9]').hasMatch(body[i + 1])) {
      lines.add(current.toString());
      current.clear();
      i += 1;
    } else if (body[i] == _backslash && i + 1 < body.length) {
      current.write(body[i]);
      current.write(body[i + 1]);
      i += 2;
    } else {
      current.write(body[i]);
      i += 1;
    }
  }
  lines.add(current.toString());
  final trimmed = lines
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  return trimmed.isEmpty ? [''] : trimmed;
}

/// `3cm`, `2.2cm`, `5pt`, or a bare number (TikZ defaults to cm).
double? _parseLengthCm(String value) {
  final match = RegExp(r'^(-?[\d.]+)\s*(cm|pt|mm|em)?$').firstMatch(value);
  if (match == null) return null;
  final number = double.tryParse(match.group(1)!);
  if (number == null) return null;
  return switch (match.group(2)) {
    'pt' => number * _cmPerPt,
    'mm' => number / 10,
    'em' => number * 10 * _cmPerPt, // 1em ≈ 10pt at documentclass 10-11pt.
    _ => number,
  };
}

/// Splits on [separator] occurrences that are outside `{}`/`[]` nesting.
List<String> _splitTopLevel(String text, String separator) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '{' || char == '[') depth++;
    if (char == '}' || char == ']') depth--;
    if (depth == 0 && char == separator) {
      parts.add(text.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(text.substring(start));
  return parts;
}

/// Index of the first top-level occurrence of [needle], -1 when absent,
/// -2 when the bracket nesting never closes.
int _topLevelIndexOf(String text, String needle) {
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '{' || char == '[') depth++;
    if (char == '}' || char == ']') depth--;
    if (depth < 0) return -2;
    if (depth == 0 && char == needle) return i;
  }
  return depth == 0 ? -1 : -2;
}

/// Index of the `]`/`}` matching the bracket at [open]; -1 when unbalanced.
int _matchingBracket(String text, int open) {
  final opener = text[open];
  final closer = opener == '[' ? ']' : '}';
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    if (text[i] == opener) depth++;
    if (text[i] == closer) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// A node with its final geometry: center position and full extent
/// (label + inner sep, at least `minimum height`), in TikZ cm with y up.
final class TikzPlacedNode {
  const TikzPlacedNode({
    required this.node,
    required this.centerX,
    required this.centerY,
    required this.widthCm,
    required this.heightCm,
  });

  final TikzNode node;
  final double centerX;
  final double centerY;
  final double widthCm;
  final double heightCm;

  double get left => centerX - widthCm / 2;
  double get right => centerX + widthCm / 2;
  double get top => centerY + heightCm / 2;
  double get bottom => centerY - heightCm / 2;
}

final class TikzResolvedDiagram {
  const TikzResolvedDiagram({
    required this.diagram,
    required this.placed,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final TikzDiagram diagram;
  final Map<String, TikzPlacedNode> placed;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  double get widthCm => maxX - minX;
  double get heightCm => maxY - minY;
}

/// Resolves every node to a concrete rect. [measureLabelCm] returns the
/// rendered size of a node's label text alone, in cm; inner sep and
/// `minimum height` are applied here. Returns null when a relative
/// placement refers forward or to a missing node.
TikzResolvedDiagram? resolveTikzLayout(
  TikzDiagram diagram,
  ({double width, double height}) Function(TikzNode node) measureLabelCm,
) {
  final placed = <String, TikzPlacedNode>{};
  for (final node in diagram.nodes) {
    final labelSize = measureLabelCm(node);
    final width = labelSize.width + 2 * node.style.innerSepCm;
    var height = labelSize.height + 2 * node.style.innerSepCm;
    if (height < node.style.minHeightCm) height = node.style.minHeightCm;
    double centerX;
    double centerY;
    switch (node.placement) {
      case TikzAbsolute(:final x, :final y):
        centerX = x * diagram.scale;
        centerY = y * diagram.scale;
      case TikzRelative(:final side, :final gapCm, :final ref):
        final anchor = placed[ref];
        if (anchor == null) return null;
        switch (side) {
          case TikzSide.above:
            centerX = anchor.centerX;
            centerY = anchor.top + gapCm + height / 2;
          case TikzSide.below:
            centerX = anchor.centerX;
            centerY = anchor.bottom - gapCm - height / 2;
          case TikzSide.left:
            centerX = anchor.left - gapCm - width / 2;
            centerY = anchor.centerY;
          case TikzSide.right:
            centerX = anchor.right + gapCm + width / 2;
            centerY = anchor.centerY;
        }
    }
    placed[node.name] = TikzPlacedNode(
      node: node,
      centerX: centerX,
      centerY: centerY,
      widthCm: width,
      heightCm: height,
    );
  }

  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  var minY = double.infinity;
  var maxY = double.negativeInfinity;
  for (final node in placed.values) {
    if (node.left < minX) minX = node.left;
    if (node.right > maxX) maxX = node.right;
    if (node.bottom < minY) minY = node.bottom;
    if (node.top > maxY) maxY = node.top;
  }
  return TikzResolvedDiagram(
    diagram: diagram,
    placed: placed,
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
  );
}
