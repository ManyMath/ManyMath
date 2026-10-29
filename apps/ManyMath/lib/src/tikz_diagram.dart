/// Pixel layout for TikZ diagrams: clips edges at node borders and places edge
/// labels. Kept apart from the parser in `tikz_model.dart`, which stays free of
/// `dart:ui` so the document parser also runs on the plain Dart VM.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'tikz_model.dart';

export 'tikz_model.dart';

/// One straight edge of a laid-out diagram, clipped to its nodes' borders.
final class TikzEdgeSegment {
  const TikzEdgeSegment({
    required this.start,
    required this.end,
    required this.arrow,
    required this.thick,
  });

  final Offset start;
  final Offset end;
  final bool arrow;
  final bool thick;
}

/// An edge label and the box it was given.
final class TikzPlacedLabel {
  const TikzPlacedLabel(this.rect, this.label);

  final Rect rect;
  final TikzEdgeLabel label;
}

/// A diagram laid out in logical pixels with y pointing down; every rect
/// and point lies inside [size].
final class TikzLayout {
  const TikzLayout({
    required this.size,
    required this.nodes,
    required this.edges,
    required this.labels,
  });

  final Size size;
  final Map<String, Rect> nodes;
  final List<TikzEdgeSegment> edges;
  final List<TikzPlacedLabel> labels;
}

/// Lays [diagram] out at [pxPerCm]. The callbacks return a label's rendered
/// size in pixels; [labelGap] separates an edge label from its edge and
/// [margin] pads the drawing. Returns null when [resolveTikzLayout] does.
TikzLayout? layoutTikzDiagram(
  TikzDiagram diagram, {
  required double pxPerCm,
  required Size Function(TikzNode node) measureNode,
  required Size Function(TikzEdgeLabel label) measureEdgeLabel,
  required double labelGap,
  required double margin,
}) {
  final resolved = resolveTikzLayout(diagram, (node) {
    final size = measureNode(node);
    return (width: size.width / pxPerCm, height: size.height / pxPerCm);
  });
  if (resolved == null) return null;

  // TikZ y points up; the canvas y points down. Flip while converting.
  final nodeRects = <String, Rect>{
    for (final MapEntry(key: name, value: placed) in resolved.placed.entries)
      name: Rect.fromCenter(
        center: Offset(
          (placed.centerX - resolved.minX) * pxPerCm,
          (resolved.maxY - placed.centerY) * pxPerCm,
        ),
        width: placed.widthCm * pxPerCm,
        height: placed.heightCm * pxPerCm,
      ),
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

  final edges = <TikzEdgeSegment>[];
  final labels = <TikzPlacedLabel>[];
  for (final edge in diagram.edges) {
    final fromRect = nodeRects[edge.from]!;
    final toRect = nodeRects[edge.to]!;
    final direction = toRect.center - fromRect.center;
    if (direction.distance == 0) continue;
    final unit = direction / direction.distance;
    final start = borderPoint(fromRect, unit);
    final end = borderPoint(toRect, -unit);
    edges.add(
      TikzEdgeSegment(
        start: start,
        end: end,
        arrow: edge.arrow,
        thick: edge.thick,
      ),
    );
    final label = edge.label;
    if (label == null) continue;
    final size = measureEdgeLabel(label);
    final gap = labelGap;

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
    // How much of the nodes and earlier labels a spot would cover.
    double covered(Rect rect) {
      final probe = rect.deflate(1);
      var area = 0.0;
      for (final other in [
        ...nodeRects.values,
        for (final placed in labels) placed.rect,
      ]) {
        if (!probe.overlaps(other)) continue;
        final overlap = probe.intersect(other);
        area += overlap.width * overlap.height;
      }
      return area;
    }

    // The first clear spot in preference order; when every spot covers
    // something, the one that covers least.
    var rect = candidates.first;
    var least = covered(rect);
    for (final candidate in candidates.skip(1)) {
      if (least == 0) break;
      final area = covered(candidate);
      if (area < least) {
        rect = candidate;
        least = area;
      }
    }
    labels.add(TikzPlacedLabel(rect, label));
  }

  // Edge labels can stick out past the node bounding box; pad the canvas
  // to whatever the drawing covers, then move everything inside it.
  var bounds = nodeRects.values.reduce((a, b) => a.expandToInclude(b));
  for (final label in labels) {
    bounds = bounds.expandToInclude(label.rect);
  }
  final shift = Offset(margin - bounds.left, margin - bounds.top);
  return TikzLayout(
    size: Size(bounds.width + 2 * margin, bounds.height + 2 * margin),
    nodes: <String, Rect>{
      for (final MapEntry(key: name, value: rect) in nodeRects.entries)
        name: rect.shift(shift),
    },
    edges: <TikzEdgeSegment>[
      for (final edge in edges)
        TikzEdgeSegment(
          start: edge.start + shift,
          end: edge.end + shift,
          arrow: edge.arrow,
          thick: edge.thick,
        ),
    ],
    labels: <TikzPlacedLabel>[
      for (final label in labels)
        TikzPlacedLabel(label.rect.shift(shift), label.label),
    ],
  );
}
