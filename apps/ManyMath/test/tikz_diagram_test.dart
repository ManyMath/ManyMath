import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manymath/src/tikz_diagram.dart';

/// The FROSTLASS crate-dependency graph, as both FROSTLASS papers embed it
/// (absolute coordinates, `every node`/`edge` styles), post comment-strip.
const _depGraph = r'''
[
    scale=1,     every node/.style={draw, rectangle, rounded corners, minimum height=1cm, font=\ttfamily, inner sep=5pt, align=center},     edge/.style={-{Latex}, thick}
]

\node (wallet) at (4, 8.5) {wallet};
\node (simple-request) at (8, 8.5) {simple-request};
\node (rpc) at (8.25, 6.5) {rpc};
\node (serai) at (2.5, 5.5) {serai};
\node (address) at (10, 3.5) {address};
\node (mlsag) at (8, 3.5) {mlsag};
\node (clsag) at (6, 3.5) {clsag};
\node (bulletproofs) at (3.5, 3.5) {bulletproofs};
\node (borromean) at (0.5, 3.5) {borromean};
\node (io) at (5, 1) {io};
\node (generators) at (2, 1) {generators};
\node (primitives) at (8, 1) {primitives};

\draw[edge] (wallet) -- (rpc);
\draw[edge] (wallet) -- (address);
\draw[edge] (wallet) -- (clsag);
\draw[edge] (wallet) -- (serai);
\draw[edge] (simple-request) -- (rpc);
\draw[edge] (rpc) -- (serai);
\draw[edge] (rpc) -- (address);
\draw[edge] (serai) -- (borromean);
\draw[edge] (serai) -- (bulletproofs);
\draw[edge] (serai) -- (clsag);
\draw[edge] (serai) -- (mlsag);
\draw[edge] (address) -- (io);
\draw[edge] (address) -- (primitives);
\draw[edge] (borromean) -- (io);
\draw[edge] (borromean) -- (generators);
\draw[edge] (borromean) -- (primitives);
\draw[edge] (bulletproofs) -- (io);
\draw[edge] (bulletproofs) -- (generators);
\draw[edge] (bulletproofs) -- (primitives);
\draw[edge] (clsag) -- (io);
\draw[edge] (clsag) -- (generators);
\draw[edge] (clsag) -- (primitives);
\draw[edge] (mlsag) -- (io);
\draw[edge] (mlsag) -- (generators);
\draw[edge] (mlsag) -- (primitives);
''';

/// The Rage Guide encryption flow chart, verbatim from the paper: relative
/// `positioning` placement, plus the Markdown-conversion artifacts the
/// interpreter normalizes (`\[` for `[`, ``` fence lines, `\\` collapsed to
/// a single backslash inside labels).
const _rageFlow = r'''
\[node distance=1.8cm, auto, >=stealth]
\node\[draw, rectangle] (plaintext) {Plaintext};
\node\[draw, rectangle, right=3cm of plaintext] (stream) {STREAM\ChaCha20-Poly1305\64 KiB chunks, 12 B nonce};
\node\[draw, rectangle, right=3cm of stream] (ciphertext) {Ciphertext};

```
\node[draw, rectangle, above=2.2cm of stream] (hkdf) {HKDF-SHA-256\\
salt = nonce (16 B)\\
ikm = file-key (16 B)\\
info = "payload"};
\node[draw, rectangle, above=2.2cm of hkdf] (nonce) {Nonce (random 16 B)};
\node[draw, rectangle, left=3cm of nonce] (filekey) {File-key (random 16 B)};
\node[draw, rectangle, below=2.2cm of filekey] (header) {HeaderV1\\recipient stanzas + 32 B HMAC};

\draw[->] (plaintext) -- (stream);
\draw[->] (stream) -- (ciphertext);
\draw[->] (hkdf) -- node[above] {payload-key (32 B)} (stream);
\draw[->] (header) -- node[left] {header.mac (32 B)} (hkdf);
\draw[->] (filekey) -- node[left] {ikm} (hkdf);
\draw[->] (nonce) -- node[right] {info} (hkdf);
\draw[->] (filekey) -- node[above] {mac\_key → HMAC key} (header);
\draw[->] (filekey) -- node[right] {file-key → wrap per recipient} (header);
```
''';

void main() {
  group('parseTikzDiagram: FROSTLASS dependency graph', () {
    final diagram = parseTikzDiagram(_depGraph);

    test('parses all nodes at their absolute coordinates', () {
      expect(diagram, isNotNull);
      expect(diagram!.nodes, hasLength(12));
      final byName = {for (final n in diagram.nodes) n.name: n};
      expect(byName.keys, contains('simple-request'));
      final rpc = byName['rpc']!.placement as TikzAbsolute;
      expect(rpc.x, 8.25);
      expect(rpc.y, 6.5);
      final io = byName['io']!.placement as TikzAbsolute;
      expect(io.x, 5);
      expect(io.y, 1);
      expect(byName['wallet']!.labelLines, ['wallet']);
    });

    test('applies the every-node style to each node', () {
      for (final node in diagram!.nodes) {
        expect(node.style.draw, isTrue, reason: node.name);
        expect(node.style.roundedCorners, isTrue);
        expect(node.style.monospace, isTrue);
        expect(node.style.minHeightCm, 1);
        // inner sep=5pt ≈ 0.176 cm.
        expect(node.style.innerSepCm, closeTo(0.176, 0.001));
      }
    });

    test('parses all edges with the arrow+thick edge style', () {
      expect(diagram!.edges, hasLength(25));
      for (final edge in diagram.edges) {
        expect(edge.arrow, isTrue);
        expect(edge.thick, isTrue);
        expect(edge.label, isNull);
      }
      expect(
        diagram.edges.map((e) => '${e.from}->${e.to}'),
        containsAll(['wallet->rpc', 'simple-request->rpc', 'mlsag->io']),
      );
    });

    test('lays out absolute nodes exactly at scaled coordinates', () {
      final resolved = resolveTikzLayout(
        diagram!,
        (node) => (width: 1.0, height: 0.5),
      );
      expect(resolved, isNotNull);
      final wallet = resolved!.placed['wallet']!;
      expect(wallet.centerX, 4);
      expect(wallet.centerY, 8.5);
      // minimum height=1cm beats label height + inner sep.
      expect(wallet.heightCm, 1);
      expect(wallet.widthCm, closeTo(1 + 2 * 0.176, 0.01));
      expect(resolved.minY, closeTo(1 - 0.5, 0.01));
      expect(resolved.maxY, closeTo(8.5 + 0.5, 0.01));
    });
  });

  group('parseTikzDiagram: rage flow chart', () {
    final diagram = parseTikzDiagram(_rageFlow);

    test('normalizes the Markdown artifacts and parses all nodes', () {
      expect(diagram, isNotNull);
      expect(diagram!.nodes.map((n) => n.name).toList(), [
        'plaintext',
        'stream',
        'ciphertext',
        'hkdf',
        'nonce',
        'filekey',
        'header',
      ]);
    });

    test('splits multi-line labels, including collapsed \\\\ artifacts', () {
      final byName = {for (final n in diagram!.nodes) n.name: n};
      expect(byName['stream']!.labelLines, [
        'STREAM',
        'ChaCha20-Poly1305',
        '64 KiB chunks, 12 B nonce',
      ]);
      expect(byName['hkdf']!.labelLines, [
        'HKDF-SHA-256',
        'salt = nonce (16 B)',
        'ikm = file-key (16 B)',
        'info = "payload"',
      ]);
      expect(byName['header']!.labelLines, [
        'HeaderV1',
        'recipient stanzas + 32 B HMAC',
      ]);
    });

    test('keeps positioning placements with their gaps', () {
      final byName = {for (final n in diagram!.nodes) n.name: n};
      expect(byName['plaintext']!.placement, isA<TikzAbsolute>());
      final stream = byName['stream']!.placement as TikzRelative;
      expect(stream.side, TikzSide.right);
      expect(stream.gapCm, 3);
      expect(stream.ref, 'plaintext');
      final header = byName['header']!.placement as TikzRelative;
      expect(header.side, TikzSide.below);
      expect(header.gapCm, 2.2);
      expect(header.ref, 'filekey');
    });

    test('parses edge labels with their sides, keeping escapes intact', () {
      expect(diagram!.edges, hasLength(8));
      final labeled = {
        for (final e in diagram.edges.where((e) => e.label != null))
          '${e.from}->${e.to}': e.label!,
      };
      expect(labeled['hkdf->stream']!.lines, ['payload-key (32 B)']);
      expect(labeled['hkdf->stream']!.side, TikzSide.above);
      expect(labeled['header->hkdf']!.side, TikzSide.left);
      expect(labeled['nonce->hkdf']!.side, TikzSide.right);
      // Both filekey->header duplicates keep their own label; \_ is left
      // for the inline pipeline, not treated as a line break.
      final duplicates = diagram.edges
          .where((e) => e.from == 'filekey' && e.to == 'header')
          .toList();
      expect(duplicates, hasLength(2));
      expect(duplicates[0].label!.lines, [r'mac\_key → HMAC key']);
      expect(duplicates[1].label!.lines, ['file-key → wrap per recipient']);
      for (final edge in diagram.edges) {
        expect(edge.arrow, isTrue);
        expect(edge.thick, isFalse);
      }
    });

    test('resolves relative placement border-to-border', () {
      // Fixed fake label metrics make the arithmetic checkable: every label
      // measures 2 cm × 0.6 cm, inner sep defaults to ~0.117 cm.
      final resolved = resolveTikzLayout(
        diagram!,
        (node) => (width: 2.0, height: 0.6),
      );
      expect(resolved, isNotNull);
      final placed = resolved!.placed;
      final plaintext = placed['plaintext']!;
      final stream = placed['stream']!;
      expect(plaintext.centerX, 0);
      expect(plaintext.centerY, 0);
      // right=3cm of plaintext: stream's west border 3 cm from plaintext's
      // east border, vertically centered on it.
      expect(stream.left, closeTo(plaintext.right + 3, 1e-9));
      expect(stream.centerY, 0);
      // above=2.2cm of stream: south border 2.2 cm above stream's north.
      final hkdf = placed['hkdf']!;
      expect(hkdf.bottom, closeTo(stream.top + 2.2, 1e-9));
      expect(hkdf.centerX, stream.centerX);
      // below=2.2cm of filekey.
      final filekey = placed['filekey']!;
      final header = placed['header']!;
      expect(header.top, closeTo(filekey.bottom - 2.2, 1e-9));
      expect(header.centerX, filekey.centerX);
      // left=3cm of nonce.
      final nonce = placed['nonce']!;
      expect(filekey.right, closeTo(nonce.left - 3, 1e-9));
    });
  });

  group('parseTikzDiagram: outside the subset', () {
    test('rejects unknown picture options', () {
      expect(parseTikzDiagram(r'[baseline=X] \node (a) {a};'), isNull);
    });

    test('rejects unknown commands', () {
      expect(parseTikzDiagram(r'\node (a) {a}; \path (a) edge (a);'), isNull);
    });

    test('rejects unknown node options', () {
      expect(parseTikzDiagram(r'\node[circle] (a) at (0,0) {a};'), isNull);
    });

    test('rejects curves and multi-segment paths', () {
      expect(
        parseTikzDiagram(
          r'\node (a) at (0,0) {a}; \node (b) at (1,1) {b};'
          r'\draw[->] (a) to[bend left] (b);',
        ),
        isNull,
      );
      expect(
        parseTikzDiagram(
          r'\node (a) at (0,0) {a}; \node (b) at (1,1) {b};'
          r'\draw[->] (a) -- (0,1) -- (b);',
        ),
        isNull,
      );
    });

    test('rejects edges to undeclared nodes', () {
      expect(
        parseTikzDiagram(r'\node (a) at (0,0) {a}; \draw[->] (a) -- (b);'),
        isNull,
      );
    });

    test('rejects forward relative placement references', () {
      expect(
        parseTikzDiagram(
          r'\node[right=1cm of b] (a) {a}; \node (b) at (0,0) {b};',
        ),
        isNull,
      );
    });

    test('rejects tikzcd-style bodies', () {
      expect(parseTikzDiagram(r'A \arrow[r] & B \\ C & D'), isNull);
    });

    test('rejects an empty picture', () {
      expect(parseTikzDiagram(''), isNull);
    });
  });

  group('document integration', () {
    test('a supported tikzpicture becomes a TikzDiagramBlock', () {
      final blocks = parseLatexDocument(
        '\\begin{tikzpicture}\n'
        r'\node[draw] (a) at (0,0) {A}; \node[draw] (b) at (2,0) {B};'
        '\n'
        r'\draw[->] (a) -- (b);'
        '\n\\end{tikzpicture}\n',
      );
      final diagrams = blocks.whereType<TikzDiagramBlock>().toList();
      expect(diagrams, hasLength(1));
      expect(diagrams.single.diagram.nodes, hasLength(2));
      expect(blocks.whereType<DiagramBlock>(), isEmpty);
    });

    test('an unsupported tikzpicture keeps the placeholder', () {
      final blocks = parseLatexDocument(
        '\\begin{tikzpicture}\n'
        r'\draw (0,0) circle (1cm);'
        '\n\\end{tikzpicture}\n',
      );
      expect(blocks.whereType<TikzDiagramBlock>(), isEmpty);
      expect(blocks.whereType<DiagramBlock>(), hasLength(1));
    });

    test('tikzcd keeps the placeholder', () {
      final blocks = parseLatexDocument(
        '\\begin{tikzcd}\nA \\arrow[r] & B\n\\end{tikzcd}\n',
      );
      expect(blocks.whereType<DiagramBlock>().single.kind, 'tikzcd');
    });
  });
}
