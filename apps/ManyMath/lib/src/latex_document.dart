/// A deliberately small LaTeX *document* model on top of ratex's *math*
/// engine.
///
/// RaTeX renders formulas; a full document page also has prose around
/// them. This parser understands just enough document LaTeX for that:
/// comments, `\begin{document}` bodies, `\maketitle` metadata, sections,
/// paragraphs with inline math and `\textbf`/`\textit`/`\emph`, single-level
/// `itemize`/`enumerate` lists, and display math (`$$...$$`, `\[...\]`, and
/// the math environments RaTeX lays out natively, like `align`). Everything
/// else passes through as plain text; the parser never throws.
///
/// Math constructs additionally carry their code-unit span in the *original*
/// source string (delimiters included), tracked through line-ending
/// normalization and comment stripping, so tooling like the error panel can
/// jump from a failed formula back to the exact editor selection.
library;

/// One block of a parsed document, in source order.
sealed class DocBlock {
  const DocBlock();
}

final class TitleBlock extends DocBlock {
  const TitleBlock({
    this.title,
    this.author,
    this.date,
    this.titleSourceMap,
    this.authorSourceMap,
    this.dateSourceMap,
  });

  final String? title;
  final String? author;
  final String? date;
  final List<int>? titleSourceMap;
  final List<int>? authorSourceMap;
  final List<int>? dateSourceMap;
}

final class HeadingBlock extends DocBlock {
  const HeadingBlock(this.level, this.spans);

  /// 1 = `\section`, 2 = `\subsection`, 3 = `\subsubsection`.
  final int level;
  final List<DocInline> spans;
}

final class ParagraphBlock extends DocBlock {
  const ParagraphBlock(this.spans);

  final List<DocInline> spans;
}

final class DisplayMathBlock extends DocBlock {
  const DisplayMathBlock(
    this.latex, {
    this.sourceStart,
    this.sourceEnd,
    this.latexSourceMap,
  });

  /// The formula source handed to RaTeX (for environments, includes the
  /// surrounding `\begin{...}...\end{...}`).
  final String latex;

  /// Code-unit span of the whole construct (delimiters included) in the
  /// original document source, when known.
  final int? sourceStart;
  final int? sourceEnd;

  /// `latexSourceMap[i]` is the original-source index of `latex[i]`, when
  /// known: the exact mapping for engine-reported error offsets (stripped
  /// comments and normalized line endings make a plain substring search
  /// unreliable).
  final List<int>? latexSourceMap;
}

/// `bullet` for `itemize`, `numbered` for `enumerate`, `description` for
/// `description` (each item's `\item[label]` is required and shown bolded
/// ahead of the item, rather than a bullet or number).
enum ListStyle { bullet, numbered, description }

final class ListBlock extends DocBlock {
  const ListBlock({required this.style, required this.items});

  final ListStyle style;

  /// Each item is a full block sequence: real papers nest lists, display
  /// math, and even theorem environments inside a single `\item`.
  final List<List<DocBlock>> items;
}

/// A verbatim-like environment (`lstlisting`, `verbatim`, `Verbatim`,
/// `minted`): shown as preformatted monospace text, with no macro or math
/// interpretation of its contents.
final class CodeBlock extends DocBlock {
  const CodeBlock(this.code);

  final String code;
}

/// One `\bibitem{key}` entry of a `\begin{thebibliography}` block, numbered
/// in declaration order (see [_collectReferences]).
final class BibliographyEntry {
  const BibliographyEntry({required this.number, required this.spans});

  final int number;
  final List<DocInline> spans;
}

final class BibliographyBlock extends DocBlock {
  const BibliographyBlock(this.entries);

  final List<BibliographyEntry> entries;
}

/// A `quote`/`quotation` environment: shown indented, set off from the
/// surrounding prose. The body is a full block sequence — quoted material
/// in real papers includes lists and display math, not just prose.
final class QuoteBlock extends DocBlock {
  const QuoteBlock(this.children);

  final List<DocBlock> children;
}

/// A `definition`/`theorem`/`lemma`/... environment (standard amsthm names
/// plus the paper's own `\newtheorem`/`\newframedtheorem` declarations).
/// [number] comes from real counter modeling over the whole document (see
/// [_collectReferences]); it is null for proofs, which LaTeX leaves
/// unnumbered.
final class TheoremBlock extends DocBlock {
  const TheoremBlock({
    required this.noun,
    this.number,
    this.title,
    required this.body,
  });

  final String noun;
  final String? number;
  final List<DocInline>? title;

  /// A full block sequence: proofs and definitions routinely contain
  /// `align*` blocks and enumerated case analyses, not just prose.
  final List<DocBlock> body;
}

/// One cell of a [TableBlock] row. [colSpan] > 1 comes from
/// `\multicolumn{n}{spec}{content}`.
final class TableCellData {
  const TableCellData(this.spans, {this.colSpan = 1});

  final List<DocInline> spans;
  final int colSpan;
}

/// A `tabular`/`tabular*`/`longtable` environment, reduced to its cell
/// grid: rule commands (`\hline`, booktabs rules) and the column spec are
/// layout hints this renderer standardizes away.
final class TableBlock extends DocBlock {
  const TableBlock(this.rows);

  final List<List<TableCellData>> rows;
}

/// A `center` environment (or float content): children shown centered.
final class CenterBlock extends DocBlock {
  const CenterBlock(this.children);

  final List<DocBlock> children;
}

/// An `mdframed` environment: children in a plain framed box.
final class FramedBlock extends DocBlock {
  const FramedBlock(this.children);

  final List<DocBlock> children;
}

/// A `\caption{...}` inside a float. [label] is the resolved "Figure 2" /
/// "Table 1" prefix, already numbered by the parser's per-kind counter.
final class CaptionBlock extends DocBlock {
  const CaptionBlock(this.label, this.spans);

  final String label;
  final List<DocInline> spans;
}

/// A drawing environment (`tikzpicture`, `tikzcd`) this renderer cannot
/// draw: shown as an explicit placeholder rather than leaked source.
final class DiagramBlock extends DocBlock {
  const DiagramBlock(this.kind, this.code);

  final String kind;
  final String code;
}

/// One `\footnote{...}`, collected during parsing and appended to the end
/// of the document; the marker at the call site is superscript digits.
final class FootnoteBlock extends DocBlock {
  const FootnoteBlock(this.number, this.spans);

  final int number;
  final List<DocInline> spans;
}

/// One run of inline content inside a paragraph, heading, or list item.
sealed class DocInline {
  const DocInline();
}

final class TextRun extends DocInline {
  const TextRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.monospace = false,
    this.underline = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool monospace;
  final bool underline;
}

final class InlineMath extends DocInline {
  const InlineMath(
    this.latex, {
    this.sourceStart,
    this.sourceEnd,
    this.latexSourceMap,
  });

  final String latex;

  /// Code-unit span of the whole construct (delimiters included) in the
  /// original document source, when known (null only when [parseInline] is
  /// called without a source map).
  final int? sourceStart;
  final int? sourceEnd;

  /// `latexSourceMap[i]` is the original-source index of `latex[i]`, when
  /// known (see [DisplayMathBlock.latexSourceMap]).
  final List<int>? latexSourceMap;
}

/// Math environments RaTeX lays out natively when passed whole.
const _mathEnvironments = {
  'equation',
  'equation*',
  'align',
  'align*',
  'alignat',
  'alignat*',
  'gather',
  'gather*',
};

/// Verbatim-like environments captured as a whole [CodeBlock]; kept in sync
/// with [_verbatimEnvironmentRe] above, which shields their `%` characters
/// from comment-stripping.
const _codeEnvironments = {'lstlisting', 'verbatim', 'Verbatim', 'minted'};

/// `amsthm`-style theorem environments captured as a [TheoremBlock], mapped
/// to the noun their number is announced with. Deliberately only the
/// standard amsthm names: a paper's own `\newenvironment`-based theorem
/// boxes (built on `mdframed`/`framed` rather than amsthm) have too much
/// custom structure to approximate safely, so those are left alone rather
/// than guessed at.
const _theoremEnvironmentNouns = {
  'definition': 'Definition',
  'defn': 'Definition',
  'theorem': 'Theorem',
  'thm': 'Theorem',
  'lemma': 'Lemma',
  'lem': 'Lemma',
  'corollary': 'Corollary',
  'cor': 'Corollary',
  'proposition': 'Proposition',
  'prop': 'Proposition',
  'remark': 'Remark',
  'rem': 'Remark',
  'claim': 'Claim',
  'observation': 'Observation',
  'example': 'Example',
  // \begin{proof} is unnumbered even when this map's general machinery
  // finds a \label inside it (rare) — see the noun == 'Proof' special case
  // in document_view.dart, which italicizes the label and appends a QED
  // mark instead of bolding a number.
  'proof': 'Proof',
};

/// What `\ref`/`\cref`/`\Cref` print for one `\label`: a resolved number
/// (`3.2`) and the noun cleveref would use (`section`, `definition`, ...).
class LabelInfo {
  const LabelInfo(this.number, this.noun);

  final String number;
  final String noun;
}

/// Maps a label's namespace prefix (the part before its first `:` — `sec:`,
/// `def:`, `eq:`, `fig:`, by LaTeX convention) to the noun `\cref` prints.
/// A prefix outside this table still gets its own sequential counter (see
/// [_collectReferences]); it just prints as a generic "item".
const _labelPrefixNouns = {
  'sec': 'section',
  'subsec': 'section',
  'ssec': 'section',
  'def': 'definition',
  'lem': 'lemma',
  'thm': 'theorem',
  'cor': 'corollary',
  'prop': 'proposition',
  'eq': 'equation',
  'eqn': 'equation',
  'fig': 'figure',
  'table': 'table',
  'tab': 'table',
  'alg': 'algorithm',
  'oracle': 'oracle',
  'game': 'game',
  'app': 'appendix',
};

/// One theorem-like environment's numbering behavior: the noun its number
/// is announced with, which counter it steps (shared counters come from
/// `\newtheorem{env}[shared]{Noun}`), and the sectioning counter it resets
/// within (`\newtheorem{env}{Noun}[section]`), if any.
class TheoremEnvSpec {
  const TheoremEnvSpec(this.noun, this.counter, this.within);

  final String noun;
  final String counter;
  final String? within;
}

/// `\newtheorem`/`\newframedtheorem` declarations anywhere in [text],
/// mapped by environment name.
Map<String, TheoremEnvSpec> _parseTheoremDecls(String text) {
  final specs = <String, TheoremEnvSpec>{};
  final decl = RegExp(
    r'\\new(?:framed)?theorem\*?\{([^}]+)\}'
    r'(?:\[([^\]]+)\])?\{([^}]+)\}(?:\[([^\]]+)\])?',
  );
  for (final m in decl.allMatches(text)) {
    final env = m.group(1)!.trim();
    specs[env] = TheoremEnvSpec(
      m.group(3)!.trim(),
      m.group(2)?.trim() ?? env,
      m.group(4)?.trim(),
    );
  }
  return specs;
}

/// Numbering specs for every theorem-like environment: the paper's own
/// declarations layered over defaults for the standard amsthm names (flat,
/// one counter per noun so `thm` and `theorem` count together).
Map<String, TheoremEnvSpec> _theoremEnvSpecs(String text) {
  return {
    for (final entry in _theoremEnvironmentNouns.entries)
      entry.key: TheoremEnvSpec(entry.value, 'noun:${entry.value}', null),
    ..._parseTheoremDecls(text),
  };
}

/// Scans [text] (the comment-stripped document body; [map] carries its
/// characters back to the original source) once for everything a reference
/// needs: `\section`-family headings (their real, dotted numbers),
/// theorem-like environments (numbered by real counter modeling over
/// [envs]), `\label` declarations, and `\bibitem` declarations inside
/// `\begin{thebibliography}` (numbered in declaration order — the numeric
/// bibliography style all of these papers use).
///
/// A `\label` inside an open theorem environment resolves to that
/// environment's number, like LaTeX's `\refstepcounter` machinery. Labels
/// outside any theorem (equations, figures, tables) are approximated by
/// grouping labels by their naming prefix and counting each group in order
/// of appearance — real papers consistently prefix labels by kind (`eq:`,
/// `fig:`, ...), so this recovers the right numbers without modeling every
/// float and equation counter.
///
/// [theoremNumbers] maps the *original-source* offset of each numbered
/// theorem environment's `\begin` to its resolved number, so the block
/// parser can show the same number the references resolve to.
({
  Map<String, LabelInfo> labels,
  Map<String, int> citations,
  Map<int, String> theoremNumbers,
})
_collectReferences(
  String text,
  List<int> map,
  Map<String, TheoremEnvSpec> envs,
) {
  final labels = <String, LabelInfo>{};
  final citations = <String, int>{};
  final theoremNumbers = <int, String>{};
  final sectionCounters = [0, 0, 0];
  final groupCounters = <String, int>{};
  final counters = <String, int>{};
  // A shared counter (\newtheorem{conj}[resul]{...}) inherits the owning
  // declaration's [within] formatting and reset behavior.
  final counterWithin = <String, String?>{
    for (final entry in envs.entries)
      if (entry.value.counter == entry.key) entry.key: entry.value.within,
  };
  // Innermost-last open theorem environments: (env name, noun, number).
  final open = <(String, String, String?)>[];
  var bibCount = 0;

  final marker = RegExp(
    r'\\(sub){0,2}section\*?\{'
    r'|\\label\{([^}]*)\}'
    r'|\\bibitem(?:\[[^\]]*\])?\{([^}]*)\}'
    r'|\\begin\{([a-zA-Z*]+)\}'
    r'|\\end\{([a-zA-Z*]+)\}',
  );
  for (final m in marker.allMatches(text)) {
    final bibKey = m.group(3);
    final labelName = m.group(2);
    final beginEnv = m.group(4);
    final endEnv = m.group(5);
    if (bibKey != null) {
      bibCount++;
      citations[bibKey] = bibCount;
    } else if (beginEnv != null) {
      final spec = envs[beginEnv];
      if (spec == null) continue;
      if (spec.noun == 'Proof') {
        open.add((beginEnv, spec.noun, null));
        continue;
      }
      final count = (counters[spec.counter] ?? 0) + 1;
      counters[spec.counter] = count;
      final within = counterWithin.containsKey(spec.counter)
          ? counterWithin[spec.counter]
          : spec.within;
      final number = switch (within) {
        'section' => '${sectionCounters[0]}.$count',
        'subsection' => '${sectionCounters[0]}.${sectionCounters[1]}.$count',
        _ => '$count',
      };
      theoremNumbers[map[m.start]] = number;
      open.add((beginEnv, spec.noun, number));
    } else if (endEnv != null) {
      final at = open.lastIndexWhere((e) => e.$1 == endEnv);
      if (at >= 0) open.removeAt(at);
    } else if (labelName != null) {
      final colon = labelName.indexOf(':');
      final prefix = colon > 0 ? labelName.substring(0, colon) : '';
      if (prefix == 'sec' || prefix == 'subsec' || prefix == 'ssec') {
        final depth = sectionCounters.lastIndexWhere((c) => c > 0);
        final number = depth < 0
            ? '?'
            : sectionCounters.sublist(0, depth + 1).join('.');
        labels[labelName] = LabelInfo(number, 'section');
      } else if (open.isNotEmpty &&
          open.last.$3 != null &&
          prefix != 'eq' &&
          prefix != 'eqn') {
        // Inside a theorem environment, \label picks up the theorem's
        // number — except equation labels, which step their own counter.
        labels[labelName] = LabelInfo(
          open.last.$3!,
          open.last.$2.toLowerCase(),
        );
      } else {
        final noun = _labelPrefixNouns[prefix] ?? 'item';
        final count = (groupCounters[prefix] ?? 0) + 1;
        groupCounters[prefix] = count;
        labels[labelName] = LabelInfo('$count', noun);
      }
    } else {
      final level = 'sub'.allMatches(m.group(0)!).length;
      sectionCounters[level]++;
      for (var i = level + 1; i < sectionCounters.length; i++) {
        sectionCounters[i] = 0;
      }
      // \newtheorem{env}{Noun}[section]: the counter restarts with the
      // sectioning counter it's declared within.
      for (final spec in envs.values) {
        final within = counterWithin.containsKey(spec.counter)
            ? counterWithin[spec.counter]
            : spec.within;
        if ((within == 'section' && level == 0) ||
            (within == 'subsection' && level <= 1)) {
          counters.remove(spec.counter);
        }
      }
    }
  }
  return (labels: labels, citations: citations, theoremNumbers: theoremNumbers);
}

/// Replaces `\ref`/`\eqref`/`\cref`/`\Cref`/`\cite` with resolved text and
/// drops `\label` entirely (a `\label` itself prints nothing in LaTeX
/// either). An unresolved target renders as `??`, matching what LaTeX
/// prints for a `\ref` with no matching `\label`.
String _resolveReferences(
  String text,
  Map<String, LabelInfo> labels,
  Map<String, int> citations,
) {
  // Deliberately doesn't also bail when labels/citations are both empty: an
  // undefined \ref must still render as "??" (matching real LaTeX), not
  // leak its raw source.
  if (!text.contains(r'\')) return text;
  final pattern = RegExp(
    r'\\label\{[^}]*\}'
    r'|\\eqref\{([^}]*)\}'
    r'|\\[Cc]ref\{([^}]*)\}'
    r'|\\ref\{([^}]*)\}'
    r'|\\cite[tp]?\{([^}]*)\}',
  );
  return text.replaceAllMapped(pattern, (m) {
    final whole = m.group(0)!;
    if (whole.startsWith(r'\label')) return '';
    final eqrefTarget = m.group(1);
    final crefTarget = m.group(2);
    final refTarget = m.group(3);
    final citeKeys = m.group(4);
    if (eqrefTarget != null) {
      return '(${labels[eqrefTarget]?.number ?? '??'})';
    }
    if (crefTarget != null) {
      final info = labels[crefTarget];
      if (info == null) return '??';
      final noun = whole.startsWith(r'\C')
          ? info.noun[0].toUpperCase() + info.noun.substring(1)
          : info.noun;
      return '$noun ${info.number}';
    }
    if (refTarget != null) {
      return labels[refTarget]?.number ?? '??';
    }
    final numbers = citeKeys!
        .split(',')
        .map((key) => citations[key.trim()]?.toString() ?? '?');
    return '[${numbers.join(', ')}]';
  });
}

/// Parses [source] into document blocks. Lenient by construction: malformed
/// input degrades to plain text rather than failing.
List<DocBlock> parseLatexDocument(String source) {
  // Normalize line endings first: CRLF/CR would defeat the blank-line
  // paragraph detection below. Both passes carry a position map back to
  // [source] so math constructs get exact editor spans.
  final normalized = _normalizeLineEndings(source);
  final stripped = _stripComments(normalized.text, normalized.map);
  var text = stripped.text;
  var map = stripped.map;
  // Scanned from the full stripped text (preamble included, before the
  // \begin{document} slice below drops it) so preamble-declared macros and
  // \newtheorem declarations are seen; see _expandTextMacros.
  final macros = _parseMacroDefs(stripped.text);
  final theoremEnvs = _theoremEnvSpecs(stripped.text);

  final title = _argOf(text, stripped.map, r'\title');
  final author = _argOf(text, stripped.map, r'\author');
  final date = _argOf(text, stripped.map, r'\date');

  // Work on the document body when a document environment is present. The
  // end marker only counts after the begin marker (a stray earlier
  // \end{document} must not produce an inverted range).
  final beginDoc = text.indexOf(r'\begin{document}');
  if (beginDoc >= 0) {
    final bodyStart = beginDoc + r'\begin{document}'.length;
    final endDoc = text.indexOf(r'\end{document}', bodyStart);
    final bodyEnd = endDoc >= 0 ? endDoc : text.length;
    text = text.substring(bodyStart, bodyEnd);
    map = map.sublist(bodyStart, bodyEnd);
  }

  // References are collected over the body only: a \begin{theorem} inside
  // a preamble \newcommand definition is a template, not an instance, and
  // must not step the theorem counters.
  final references = _collectReferences(text, map, theoremEnvs);
  final labels = references.labels;
  final citations = references.citations;

  // Footnotes are spliced out before block parsing: the call site keeps a
  // superscript-digit marker and the bodies render as end notes, so a
  // \footnote deep inside any environment still surfaces.
  final footnoteBodies = <({String text, List<int> map})>[];
  final spliced = _extractFootnotes(text, map, footnoteBodies);
  text = spliced.text;
  map = spliced.map;

  final parser = _BlockParser(
    macros: macros,
    labels: labels,
    citations: citations,
    theoremEnvs: theoremEnvs,
    theoremNumbers: references.theoremNumbers,
    title: title,
    author: author,
    date: date,
  );
  final blocks = parser.parse(text, map);
  for (final (index, note) in footnoteBodies.indexed) {
    blocks.add(FootnoteBlock(index + 1, parser._inline(note.text, note.map)));
  }
  return blocks;
}

const _superscriptDigits = '⁰¹²³⁴⁵⁶⁷⁸⁹';

String _superscriptNumber(int n) =>
    n.toString().split('').map((d) => _superscriptDigits[int.parse(d)]).join();

/// Splices every `\footnote{...}` (and its optional `[number]`) out of
/// [text], leaving a superscript-digit marker mapped back to the
/// `\footnote` call site, and collects the bodies (with their own source
/// maps) into [out].
({String text, List<int> map}) _extractFootnotes(
  String text,
  List<int> map,
  List<({String text, List<int> map})> out,
) {
  if (!text.contains(r'\footnote')) return (text: text, map: map);
  final buf = StringBuffer();
  final outMap = <int>[];
  final marker = RegExp(r'\\footnote(?![a-zA-Z])');
  var i = 0;
  while (i < text.length) {
    if (text[i] == r'\' && text.startsWith(r'\\', i)) {
      buf.write(r'\\');
      outMap
        ..add(map[i])
        ..add(map[i + 1]);
      i += 2;
      continue;
    }
    final m = marker.matchAsPrefix(text, i);
    if (m == null) {
      buf.write(text[i]);
      outMap.add(map[i]);
      i++;
      continue;
    }
    var at = _skipSpaces(text, m.end);
    if (at < text.length && text[at] == '[') {
      final close = text.indexOf(']', at);
      if (close > 0) at = _skipSpaces(text, close + 1);
    }
    final arg = at < text.length && text[at] == '{'
        ? _balancedArg(text, at)
        : null;
    if (arg == null) {
      buf.write(text[i]);
      outMap.add(map[i]);
      i++;
      continue;
    }
    out.add((text: arg.$1, map: map.sublist(at + 1, at + 1 + arg.$1.length)));
    for (final unit in _superscriptNumber(out.length).codeUnits) {
      buf.writeCharCode(unit);
      outMap.add(map[i]);
    }
    i = arg.$2;
  }
  return (text: buf.toString(), map: outMap);
}

/// The block-level parse loop, recursive so that environments whose bodies
/// are themselves block sequences (theorems, quotes, list items) render
/// nested display math and lists instead of leaking them as raw text.
class _BlockParser {
  _BlockParser({
    required this.macros,
    required this.labels,
    required this.citations,
    this.theoremEnvs = const {},
    this.theoremNumbers = const {},
    this.title,
    this.author,
    this.date,
  });

  final Map<String, MacroDefinition> macros;
  final Map<String, LabelInfo> labels;
  final Map<String, int> citations;

  /// Theorem-like environments (standard amsthm names plus the paper's own
  /// `\newtheorem`/`\newframedtheorem` declarations) and, keyed by
  /// original-source offset of each instance's `\begin`, the number the
  /// counter model assigned it (see [_collectReferences]).
  final Map<String, TheoremEnvSpec> theoremEnvs;
  final Map<int, String> theoremNumbers;
  final ({String value, List<int> sourceMap})? title;
  final ({String value, List<int> sourceMap})? author;
  final ({String value, List<int> sourceMap})? date;

  /// Enclosing float kinds ("Figure", "Table", ...) while parsing float
  /// bodies, so a \caption knows which counter it advances.
  final List<String> _floatStack = [];

  /// Captions seen so far per kind, in document order — how LaTeX numbers
  /// figures and tables.
  final Map<String, int> _captionCounts = {};

  List<DocInline> _inline(String content, List<int>? sourceMap) {
    return parseInline(
      content,
      macros: macros,
      labels: labels,
      citations: citations,
      sourceMap: sourceMap,
    );
  }

  /// Parses one block sequence. [map] carries each character of [text] back
  /// to the original document source (see [parseLatexDocument]).
  List<DocBlock> parse(String text, List<int> map) {
    final blocks = <DocBlock>[];
    final paragraph = StringBuffer();
    // Stripped-text index of the first character in the buffer. Everything a
    // paragraph accumulates is contiguous in the stripped text (block
    // constructs flush before consuming), so one start index suffices.
    var paragraphStart = -1;

    void writeParagraph(int at, String chunk) {
      if (paragraph.isEmpty) paragraphStart = at;
      paragraph.write(chunk);
    }

    void flushParagraph() {
      final raw = paragraph.toString();
      paragraph.clear();
      final content = raw.trim();
      if (content.isEmpty) return;
      final leading = raw.length - raw.trimLeft().length;
      final start = paragraphStart + leading;
      final spans = _inline(
        content,
        map.sublist(start, start + content.length),
      );
      if (spans.isNotEmpty) blocks.add(ParagraphBlock(spans));
    }

    var i = 0;
    while (i < text.length) {
      // Blank line: paragraph boundary.
      final blank = RegExp(r'\n[ \t]*\n').matchAsPrefix(text, i);
      if (blank != null) {
        flushParagraph();
        i = blank.end;
        continue;
      }

      // Escape pairs, consumed before any delimiter matching so that the
      // second backslash of `\\[2pt]` never opens `\[` display math and an
      // escaped dollar in `\$$x$` never opens `$$`. The pairs pass through
      // verbatim; parseInline interprets them later.
      if (text.startsWith(r'\\', i) ||
          (text[i] == r'\' &&
              i + 1 < text.length &&
              r'$%&_{}#'.contains(text[i + 1]))) {
        writeParagraph(i, text.substring(i, i + 2));
        i += 2;
        continue;
      }

      // Display math: $$...$$ and \[...\].
      final dollars = _delimited(text, i, r'$$', r'$$');
      if (dollars != null) {
        flushParagraph();
        blocks.add(
          DisplayMathBlock(
            dollars.$1.trim(),
            sourceStart: map[i],
            sourceEnd: _spanEnd(map, dollars.$2),
            latexSourceMap: _trimmedSlice(map, text, i + 2, dollars.$2 - 2),
          ),
        );
        i = dollars.$2;
        continue;
      }
      // A single $ opens inline math; consume the whole span verbatim into
      // the paragraph (parseInline interprets it later). Without this, the
      // adjacent closers/openers in '$a$$b$' would read as a $$ display
      // opener and swallow the rest of the document.
      if (text.startsWith(r'$', i)) {
        final inline = _delimited(text, i, r'$', r'$');
        if (inline != null) {
          writeParagraph(i, text.substring(i, inline.$2));
          i = inline.$2;
          continue;
        }
      }
      final bracket = _delimited(text, i, r'\[', r'\]');
      if (bracket != null) {
        flushParagraph();
        blocks.add(
          DisplayMathBlock(
            bracket.$1.trim(),
            sourceStart: map[i],
            sourceEnd: _spanEnd(map, bracket.$2),
            latexSourceMap: _trimmedSlice(map, text, i + 2, bracket.$2 - 2),
          ),
        );
        i = bracket.$2;
        continue;
      }

      // Environments: math ones become display blocks, lists become lists.
      final env = RegExp(r'\\begin\{([a-zA-Z*]+)\}').matchAsPrefix(text, i);
      if (env != null) {
        final name = env.group(1)!;
        final end = _matchingEnvEnd(text, name, env.end);
        if (end >= 0) {
          final body = text.substring(env.end, end);
          final next = end + '\\end{$name}'.length;
          if (_mathEnvironments.contains(name)) {
            flushParagraph();
            blocks.add(
              DisplayMathBlock(
                text.substring(i, next).trim(),
                sourceStart: map[i],
                sourceEnd: _spanEnd(map, next),
                latexSourceMap: _trimmedSlice(map, text, i, next),
              ),
            );
            i = next;
            continue;
          }
          if (_codeEnvironments.contains(name)) {
            flushParagraph();
            var code = body;
            // A `[options]` group (lstlisting/minted) or minted's required
            // `{lang}` argument sits directly against `\begin{name}}`, with no
            // line break before it, so it can't be mistaken for a first line
            // of code that happens to start with `[` or `{`.
            final leadingOptions = RegExp(r'^\[[^\n]*\]').matchAsPrefix(code);
            if (leadingOptions != null) {
              code = code.substring(leadingOptions.end);
            }
            final leadingArg = RegExp(r'^\{[^\n{}]*\}').matchAsPrefix(code);
            if (leadingArg != null) code = code.substring(leadingArg.end);
            // The line break right after \begin{...} (and its trailing one
            // before \end{...}) is formatting, not code.
            if (code.startsWith('\n')) code = code.substring(1);
            if (code.endsWith('\n')) code = code.substring(0, code.length - 1);
            blocks.add(CodeBlock(code));
            i = next;
            continue;
          }
          if (name == 'itemize' ||
              name == 'enumerate' ||
              name == 'description') {
            flushParagraph();
            // \item only, not \itemsep and friends, and only at this list's
            // own nesting depth — an \item inside a nested environment
            // belongs to that environment, not this list. Content before the
            // first \item (typically spacing commands like \itemsep0pt) is
            // not a bullet. Each item's body is a full recursive block parse,
            // so nested lists and display math render properly.
            final marks = _topLevelItemMarks(body);
            final items = <List<DocBlock>>[];
            for (var k = 0; k < marks.length; k++) {
              final segStart = marks[k].end;
              final segEnd = k + 1 < marks.length
                  ? marks[k + 1].start
                  : body.length;
              final label = _stripItemLabel(body.substring(segStart, segEnd));
              final segment = label.$1;
              if (segment.trim().isEmpty && label.$3 == null) continue;
              final start = env.end + segStart + label.$2;
              final itemBlocks = parse(
                segment,
                map.sublist(start, start + segment.length),
              );
              // \description's `[label]` is the item's required title, not an
              // optional override like itemize/enumerate's, so it's shown
              // (bolded) instead of being dropped — merged into the item's
              // first paragraph so it stays run-in.
              if (name == 'description' && label.$3 != null) {
                // The label is real LaTeX (papers put \texttt/custom macros
                // in there), parsed with bold as description labels are set.
                final labelRuns = <DocInline>[
                  ...parseInline(
                    label.$3!.trim(),
                    bold: true,
                    macros: macros,
                    labels: labels,
                    citations: citations,
                  ),
                  const TextRun(' '),
                ];
                if (itemBlocks.isNotEmpty &&
                    itemBlocks.first is ParagraphBlock) {
                  final first = itemBlocks.first as ParagraphBlock;
                  itemBlocks[0] = ParagraphBlock([
                    ...labelRuns,
                    ...first.spans,
                  ]);
                } else {
                  itemBlocks.insert(0, ParagraphBlock(labelRuns));
                }
              }
              items.add(itemBlocks);
            }
            if (items.isNotEmpty) {
              final style = switch (name) {
                'enumerate' => ListStyle.numbered,
                'description' => ListStyle.description,
                _ => ListStyle.bullet,
              };
              blocks.add(ListBlock(style: style, items: items));
            }
            i = next;
            continue;
          }
          if (name == 'thebibliography') {
            flushParagraph();
            var bibBody = body;
            var bibBodyStart = env.end;
            // Skip the required {widest-label} argument, e.g.
            // \begin{thebibliography}{99}.
            if (bibBody.startsWith('{')) {
              final arg = _balancedArg(bibBody, 0);
              if (arg != null) {
                bibBody = bibBody.substring(arg.$2);
                bibBodyStart += arg.$2;
              }
            }
            final marks = RegExp(
              r'\\bibitem(?:\[[^\]]*\])?\{([^}]*)\}',
            ).allMatches(bibBody).toList();
            final entries = <BibliographyEntry>[];
            for (var k = 0; k < marks.length; k++) {
              final key = marks[k].group(1)!;
              final segStart = marks[k].end;
              final segEnd = k + 1 < marks.length
                  ? marks[k + 1].start
                  : bibBody.length;
              final segment = bibBody.substring(segStart, segEnd);
              final leading = segment.length - segment.trimLeft().length;
              final trimmed = segment.trim();
              if (trimmed.isEmpty) continue;
              final start = bibBodyStart + segStart + leading;
              entries.add(
                BibliographyEntry(
                  number: citations[key] ?? (k + 1),
                  spans: _inline(
                    trimmed,
                    map.sublist(start, start + trimmed.length),
                  ),
                ),
              );
            }
            entries.sort((a, b) => a.number.compareTo(b.number));
            if (entries.isNotEmpty) blocks.add(BibliographyBlock(entries));
            i = next;
            continue;
          }
          if (name == 'quote' || name == 'quotation') {
            flushParagraph();
            final children = parse(body, map.sublist(env.end, end));
            if (children.isNotEmpty) blocks.add(QuoteBlock(children));
            i = next;
            continue;
          }
          if (name == 'abstract') {
            flushParagraph();
            blocks.add(
              const HeadingBlock(2, [TextRun('Abstract', bold: true)]),
            );
            blocks.addAll(parse(body, map.sublist(env.end, end)));
            i = next;
            continue;
          }
          // Floats: content parses in place (this renderer has no page
          // layout to float around), centered as floats conventionally are;
          // the [htbp] placement hint is dropped.
          const floatKinds = {
            'figure': 'Figure',
            'figure*': 'Figure',
            'table': 'Table',
            'table*': 'Table',
            // \DeclareCaptionType floats used by the FROSTLASS paper.
            'oracle': 'Oracle',
            'game': 'Game',
          };
          final floatKind = floatKinds[name];
          if (floatKind != null) {
            flushParagraph();
            var floatBody = body;
            var floatStart = env.end;
            if (floatBody.startsWith('[')) {
              final close = floatBody.indexOf(']');
              if (close >= 0) {
                floatBody = floatBody.substring(close + 1);
                floatStart += close + 1;
              }
            }
            _floatStack.add(floatKind);
            final children = parse(
              floatBody,
              map.sublist(floatStart, floatStart + floatBody.length),
            );
            _floatStack.removeLast();
            if (children.isNotEmpty) blocks.add(CenterBlock(children));
            i = next;
            continue;
          }
          if (name == 'center') {
            flushParagraph();
            final children = parse(body, map.sublist(env.end, end));
            if (children.isNotEmpty) blocks.add(CenterBlock(children));
            i = next;
            continue;
          }
          // minipage/suboracle: a width-constrained box; the content parses
          // in place, the [pos]{width} arguments are layout hints.
          if (name == 'minipage' || name == 'suboracle') {
            flushParagraph();
            var boxBody = body;
            var boxStart = env.end;
            if (boxBody.startsWith('[')) {
              final close = boxBody.indexOf(']');
              if (close >= 0) {
                boxBody = boxBody.substring(close + 1);
                boxStart += close + 1;
              }
            }
            final width = boxBody.startsWith('{')
                ? _balancedArg(boxBody, 0)
                : null;
            if (width != null) {
              boxBody = boxBody.substring(width.$2);
              boxStart += width.$2;
            }
            blocks.addAll(
              parse(boxBody, map.sublist(boxStart, boxStart + boxBody.length)),
            );
            i = next;
            continue;
          }
          if (name == 'mdframed') {
            flushParagraph();
            var boxBody = body;
            var boxStart = env.end;
            if (boxBody.startsWith('[')) {
              final close = boxBody.indexOf(']');
              if (close >= 0) {
                boxBody = boxBody.substring(close + 1);
                boxStart += close + 1;
              }
            }
            final children = parse(
              boxBody,
              map.sublist(boxStart, boxStart + boxBody.length),
            );
            if (children.isNotEmpty) blocks.add(FramedBlock(children));
            i = next;
            continue;
          }
          // appendices (the appendix package) wraps trailing sections but
          // adds nothing visible itself.
          if (name == 'appendices') {
            flushParagraph();
            blocks.addAll(parse(body, map.sublist(env.end, end)));
            i = next;
            continue;
          }
          if (name == 'tabular' || name == 'tabular*' || name == 'longtable') {
            flushParagraph();
            final table = _parseTabular(name, body);
            if (table != null) blocks.add(table);
            i = next;
            continue;
          }
          if (name == 'tikzpicture' || name == 'tikzcd') {
            flushParagraph();
            blocks.add(DiagramBlock(name, body.trim()));
            i = next;
            continue;
          }
          final theoremNoun =
              theoremEnvs[name]?.noun ?? _theoremEnvironmentNouns[name];
          if (theoremNoun != null) {
            flushParagraph();
            var theoremBody = body;
            var theoremBodyStart = env.end;
            // An optional [Title], e.g. \begin{definition}[Random Oracle].
            List<DocInline>? title;
            if (theoremBody.startsWith('[')) {
              final close = theoremBody.indexOf(']');
              if (close >= 0) {
                final titleText = theoremBody.substring(1, close);
                final titleStart = theoremBodyStart + 1;
                title = _inline(
                  titleText,
                  map.sublist(titleStart, titleStart + titleText.length),
                );
                theoremBody = theoremBody.substring(close + 1);
                theoremBodyStart += close + 1;
              }
            }
            // The number the counter model assigned this instance (see
            // _collectReferences), keyed by the \begin's original-source
            // offset so it survives all the recursive slicing above; null
            // for proofs, which LaTeX leaves unnumbered.
            final number = theoremNumbers[map[i]];
            blocks.add(
              TheoremBlock(
                noun: theoremNoun,
                number: number,
                title: title,
                body: parse(
                  theoremBody,
                  map.sublist(
                    theoremBodyStart,
                    theoremBodyStart + theoremBody.length,
                  ),
                ),
              ),
            );
            i = next;
            continue;
          }
        }
        // Unknown or unterminated environment: fall through as text.
      }

      // \caption{...}: a numbered "Figure N:"/"Table N:" line, the kind
      // taken from the enclosing float (see _floatStack).
      final caption = RegExp(r'\\caption(?![a-zA-Z])').matchAsPrefix(text, i);
      if (caption != null) {
        var at = _skipSpaces(text, caption.end);
        if (at < text.length && text[at] == '[') {
          final close = text.indexOf(']', at);
          if (close > 0) at = _skipSpaces(text, close + 1);
        }
        final arg = at < text.length && text[at] == '{'
            ? _balancedArg(text, at)
            : null;
        if (arg != null) {
          flushParagraph();
          final kind = _floatStack.isNotEmpty ? _floatStack.last : 'Figure';
          final count = (_captionCounts[kind] ?? 0) + 1;
          _captionCounts[kind] = count;
          blocks.add(
            CaptionBlock(
              '$kind $count',
              _inline(arg.$1, map.sublist(at + 1, at + 1 + arg.$1.length)),
            ),
          );
          i = arg.$2;
          continue;
        }
      }

      // Sections and \maketitle, recognized at any position.
      final section = RegExp(
        r'\\(sub){0,2}section\*?\{',
      ).matchAsPrefix(text, i);
      if (section != null) {
        final arg = _balancedArg(text, section.end - 1);
        if (arg != null) {
          flushParagraph();
          final level = 'sub'.allMatches(section[0]!).length + 1;
          blocks.add(
            HeadingBlock(
              level,
              _inline(
                arg.$1,
                map.sublist(section.end, section.end + arg.$1.length),
              ),
            ),
          );
          i = arg.$2;
          continue;
        }
      }
      if (text.startsWith(r'\maketitle', i)) {
        flushParagraph();
        blocks.add(
          TitleBlock(
            title: title?.value,
            author: author?.value,
            date: date?.value,
            titleSourceMap: title?.sourceMap,
            authorSourceMap: author?.sourceMap,
            dateSourceMap: date?.sourceMap,
          ),
        );
        i += r'\maketitle'.length;
        continue;
      }

      writeParagraph(i, text[i]);
      i++;
    }
    flushParagraph();
    return blocks;
  }

  /// Reduces a `tabular` body to its cell grid. Rows split at depth-0
  /// `\\`, cells at depth-0 `&` (depth counts braces and nested
  /// environments, so a nested tabular or a `\text{a \& b}` never splits
  /// the outer grid); rule commands are dropped and `\multicolumn`
  /// becomes a spanning cell.
  TableBlock? _parseTabular(String name, String body) {
    var at = 0;
    // tabular* has a leading {width} argument.
    if (name == 'tabular*') {
      at = _skipSpaces(body, at);
      final width = at < body.length && body[at] == '{'
          ? _balancedArg(body, at)
          : null;
      if (width != null) at = width.$2;
    }
    at = _skipSpaces(body, at);
    if (at < body.length && body[at] == '[') {
      final close = body.indexOf(']', at);
      if (close > 0) at = close + 1;
    }
    at = _skipSpaces(body, at);
    final colspec = at < body.length && body[at] == '{'
        ? _balancedArg(body, at)
        : null;
    if (colspec != null) at = colspec.$2;

    final cellRanges = <List<(int, int)>>[[]];
    var braceDepth = 0;
    var envDepth = 0;
    var cellStart = at;
    var i = at;
    void endCell(int end) => cellRanges.last.add((cellStart, end));
    while (i < body.length) {
      if (body[i] == r'\') {
        if (body.startsWith(r'\begin{', i)) {
          envDepth++;
          i += r'\begin{'.length;
          continue;
        }
        if (body.startsWith(r'\end{', i)) {
          if (envDepth > 0) envDepth--;
          i += r'\end{'.length;
          continue;
        }
        if (body.startsWith(r'\\', i) && braceDepth == 0 && envDepth == 0) {
          endCell(i);
          cellRanges.add([]);
          i += 2;
          final length = RegExp(r'\s*\[[^\]\n]*\]').matchAsPrefix(body, i);
          if (length != null) i = length.end;
          cellStart = i;
          continue;
        }
        i += 2;
        continue;
      }
      if (body[i] == '{') {
        braceDepth++;
        i++;
        continue;
      }
      if (body[i] == '}') {
        if (braceDepth > 0) braceDepth--;
        i++;
        continue;
      }
      if (body[i] == '&' && braceDepth == 0 && envDepth == 0) {
        endCell(i);
        cellStart = i + 1;
        i++;
        continue;
      }
      i++;
    }
    endCell(body.length);

    final rules = RegExp(
      r'\\(hline|toprule|midrule|bottomrule|centering|arraybackslash|small|footnotesize|scriptsize)(?![a-zA-Z])'
      r'|\\(cline|hhline|cmidrule|arrayrulecolor|rowcolor|addlinespace)\*?(\([^)]*\))?(\[[^\]]*\])?(\{[^}]*\})?',
    );
    final rows = <List<TableCellData>>[];
    for (final row in cellRanges) {
      final cells = <TableCellData>[];
      var hasContent = false;
      for (final (start, end) in row) {
        var content = body.substring(start, end).replaceAll(rules, ' ').trim();
        var colSpan = 1;
        final multi = RegExp(r'^\\multicolumn\s*').matchAsPrefix(content);
        if (multi != null) {
          var j = multi.end;
          final n = j < content.length && content[j] == '{'
              ? _balancedArg(content, j)
              : null;
          if (n != null) {
            j = _skipSpaces(content, n.$2);
            final spec = j < content.length && content[j] == '{'
                ? _balancedArg(content, j)
                : null;
            if (spec != null) {
              j = _skipSpaces(content, spec.$2);
              final inner = j < content.length && content[j] == '{'
                  ? _balancedArg(content, j)
                  : null;
              if (inner != null) {
                colSpan = int.tryParse(n.$1.trim()) ?? 1;
                content = inner.$1.trim();
              }
            }
          }
        }
        if (content.isNotEmpty) hasContent = true;
        cells.add(
          TableCellData(
            content.isEmpty ? const [] : _inline(content, null),
            colSpan: colSpan < 1 ? 1 : colSpan,
          ),
        );
      }
      if (hasContent) rows.add(cells);
    }
    return rows.isEmpty ? null : TableBlock(rows);
  }
}

/// The depth-0 `\item` marks of a list environment's body: an `\item`
/// inside a nested `\begin{...}...\end{...}` (an inner list, a minipage, a
/// verbatim block) belongs to that inner environment, not this list.
List<RegExpMatch> _topLevelItemMarks(String body) {
  final marks = <RegExpMatch>[];
  var depth = 0;
  final token = RegExp(
    r'\\begin\{[a-zA-Z*]+\}|\\end\{[a-zA-Z*]+\}|\\item(?![a-zA-Z])',
  );
  for (final m in token.allMatches(body)) {
    final matched = m.group(0)!;
    if (matched.startsWith(r'\begin')) {
      depth++;
    } else if (matched.startsWith(r'\end')) {
      if (depth > 0) depth--;
    } else if (depth == 0) {
      marks.add(m);
    }
  }
  return marks;
}

/// Parses inline content: `$...$`, `\(...\)`, `\textbf{}`, `\textit{}`,
/// `\emph{}`, common escapes, and `\\` as a line break.
///
/// When [sourceMap] is given (`sourceMap[i]` = index in the original
/// document of `source[i]`), [InlineMath] spans carry original-source
/// positions; otherwise their spans are null.
List<DocInline> parseInline(
  String source, {
  bool bold = false,
  bool italic = false,
  bool monospace = false,
  bool underline = false,
  Map<String, MacroDefinition> macros = const {},
  Map<String, LabelInfo> labels = const {},
  Map<String, int> citations = const {},
  List<int>? sourceMap,
}) {
  assert(
    sourceMap == null || sourceMap.length == source.length,
    'sourceMap must align 1:1 with source',
  );
  {
    var expanded = macros.isEmpty ? source : _expandTextMacros(source, macros);
    // Not gated on labels/citations being non-empty: an undefined \ref
    // must still resolve to "??" (matching real LaTeX) rather than leak
    // its raw source, so this always runs when there's a backslash at all
    // (see _resolveReferences).
    expanded = _resolveReferences(expanded, labels, citations);
    if (expanded != source) {
      source = expanded;
      // The expansion changed the text's length/content, so per-character
      // source positions no longer line up; math discovered inside an
      // expanded macro loses its precise jump-to-source target rather than
      // pointing at the wrong place.
      sourceMap = null;
    }
  }
  final spans = <DocInline>[];
  final run = StringBuffer();

  void flushRun() {
    if (run.isEmpty) return;
    final content = run.toString();
    run.clear();
    // Collapse whitespace runs (LaTeX treats newlines as spaces).
    final collapsed = content.replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isNotEmpty) {
      spans.add(
        TextRun(
          collapsed,
          bold: bold,
          italic: italic,
          monospace: monospace,
          underline: underline,
        ),
      );
    }
  }

  void addMath(
    String latex,
    int constructStart,
    int constructEnd,
    int delimiterLength,
  ) {
    flushRun();
    spans.add(
      InlineMath(
        latex,
        sourceStart: sourceMap == null ? null : sourceMap[constructStart],
        sourceEnd: sourceMap == null ? null : _spanEnd(sourceMap, constructEnd),
        latexSourceMap: sourceMap == null
            ? null
            : _trimmedSlice(
                sourceMap,
                source,
                constructStart + delimiterLength,
                constructEnd - delimiterLength,
              ),
      ),
    );
  }

  var i = 0;
  while (i < source.length) {
    // Escapes first so \$ never opens math.
    const escapes = {
      r'\$': r'$',
      r'\%': '%',
      r'\&': '&',
      r'\_': '_',
      r'\{': '{',
      r'\}': '}',
      r'\#': '#',
    };
    final escape = escapes.entries
        .where((e) => source.startsWith(e.key, i))
        .firstOrNull;
    if (escape != null) {
      run.write(escape.value);
      i += escape.key.length;
      continue;
    }
    if (source.startsWith(r'\\', i)) {
      flushRun();
      spans.add(const TextRun('\n'));
      i += 2;
      // Swallow the optional length argument of a line break (`\\[2pt]`)
      // instead of rendering "[2pt]" as text.
      final length = RegExp(r'\[[^\]\n]*\]').matchAsPrefix(source, i);
      if (length != null) i = length.end;
      continue;
    }

    // Display math reaching inline context (e.g. inside a list item)
    // degrades to inline math rather than leaking stray dollar signs.
    final doubleDollar = _delimited(source, i, r'$$', r'$$');
    if (doubleDollar != null && doubleDollar.$1.trim().isNotEmpty) {
      addMath(doubleDollar.$1.trim(), i, doubleDollar.$2, 2);
      i = doubleDollar.$2;
      continue;
    }
    final dollar = _delimited(source, i, r'$', r'$');
    if (dollar != null && dollar.$1.trim().isNotEmpty) {
      addMath(dollar.$1.trim(), i, dollar.$2, 1);
      i = dollar.$2;
      continue;
    }
    final paren = _delimited(source, i, r'\(', r'\)');
    if (paren != null && paren.$1.trim().isNotEmpty) {
      addMath(paren.$1.trim(), i, paren.$2, 2);
      i = paren.$2;
      continue;
    }
    // \[...\] display math reaching inline context degrades to inline math
    // too, instead of leaking raw LaTeX.
    final bracket = _delimited(source, i, r'\[', r'\]');
    if (bracket != null && bracket.$1.trim().isNotEmpty) {
      addMath(bracket.$1.trim(), i, bracket.$2, 2);
      i = bracket.$2;
      continue;
    }

    // Two-argument commands: the first argument (URL, color name) isn't
    // shown, so only the second is flushed, recursively parsed and
    // inheriting the current styles.
    const twoArgCommands = {r'\href', r'\textcolor'};
    final twoArgCommand = twoArgCommands
        .where((name) => source.startsWith('$name{', i))
        .firstOrNull;
    if (twoArgCommand != null) {
      final firstEnd = _balancedArg(source, i + twoArgCommand.length)?.$2;
      if (firstEnd != null) {
        final secondStart = _skipSpaces(source, firstEnd);
        final second = _balancedArg(source, secondStart);
        if (second != null) {
          flushRun();
          spans.addAll(
            parseInline(
              second.$1,
              bold: bold,
              italic: italic,
              monospace: monospace,
              underline: underline,
              macros: macros,
              labels: labels,
              citations: citations,
              sourceMap: sourceMap?.sublist(
                secondStart + 1,
                secondStart + 1 + second.$1.length,
              ),
            ),
          );
          i = second.$2;
          continue;
        }
      }
    }
    // TeX accent commands (\'e, \"{u}, \c{c}, ...): approximated with a
    // Unicode combining mark placed after the base letter, which text
    // shaping renders merged with it — simpler and more general than a
    // lookup table of every accent/letter combination, and covers letters
    // this parser has never seen.
    if (source.startsWith(r'\', i)) {
      final marker = i + 1 < source.length ? source[i + 1] : null;
      final symbolMark = marker == null ? null : _accentSymbolMarks[marker];
      final letterMark =
          symbolMark == null &&
              marker != null &&
              i + 2 < source.length &&
              source[i + 2] == '{'
          ? _accentLetterMarks[marker]
          : null;
      final mark = symbolMark ?? letterMark;
      if (mark != null) {
        final based = _accentBase(source, i + 2);
        if (based != null) {
          final content = based.$1;
          run.write(content[0] + mark + content.substring(1));
          i = based.$2;
          continue;
        }
        // Declined (e.g. \"{\i}, the dotless-i idiom): keep the whole
        // construct as one literal run — the bare-group handling below
        // must not strip its braces and re-interpret the inside.
        if (i + 2 < source.length && source[i + 2] == '{') {
          final group = _balancedArg(source, i + 2);
          if (group != null) {
            run.write(source.substring(i, group.$2));
            i = group.$2;
            continue;
          }
        }
      }
    }

    // \url and \path's arguments are verbatim (LaTeX doesn't interpret `_`,
    // `%`, etc. inside them), so they're taken as-is rather than
    // recursively parsed.
    const verbatimCommands = {r'\url', r'\path'};
    final verbatimCommand = verbatimCommands
        .where((name) => source.startsWith('$name{', i))
        .firstOrNull;
    if (verbatimCommand != null) {
      final arg = _balancedArg(source, i + verbatimCommand.length);
      if (arg != null) {
        flushRun();
        spans.add(
          TextRun(
            arg.$1,
            bold: bold,
            italic: italic,
            monospace: true,
            underline: underline,
          ),
        );
        i = arg.$2;
        continue;
      }
    }

    // An unescaped ~ is a non-breaking space, not a literal tilde.
    if (source[i] == '~') {
      run.write(' ');
      i++;
      continue;
    }
    // A bare {...} group scopes declarations (`{\ttfamily code}`); recurse
    // so the group's own style switches end at its closing brace and the
    // braces themselves never show.
    if (source[i] == '{') {
      final group = _balancedArg(source, i);
      if (group != null && group.$1.isEmpty) {
        // An empty group is invisible but still a token boundary: after an
        // unexpanded control word (`\to{}b`, see _expandTextMacros) a
        // zero-width space keeps the following letter from reading as part
        // of the control word.
        if (RegExp(r'\\[a-zA-Z]+$').hasMatch(run.toString())) {
          run.write('​');
        }
        i = group.$2;
        continue;
      }
      if (group != null) {
        flushRun();
        spans.addAll(
          parseInline(
            group.$1,
            bold: bold,
            italic: italic,
            monospace: monospace,
            underline: underline,
            macros: macros,
            labels: labels,
            citations: citations,
            sourceMap: sourceMap?.sublist(i + 1, i + 1 + group.$1.length),
          ),
        );
        i = group.$2;
        continue;
      }
    }
    // A stray closing brace (its opener was consumed by an outer construct)
    // prints nothing.
    if (source[i] == '}') {
      i++;
      continue;
    }

    // Control-symbol spacing commands (no letter after the backslash, so
    // the word-boundary logic below doesn't apply to them).
    const controlSymbols = {
      r'\ ': ' ',
      r'\,': ' ',
      r'\;': ' ',
      r'\:': ' ',
      r'\!': '',
      r'\/': '',
      r'\@': '',
    };
    final controlSymbol = controlSymbols.entries
        .where((e) => source.startsWith(e.key, i))
        .firstOrNull;
    if (controlSymbol != null) {
      run.write(controlSymbol.value);
      i += 2;
      continue;
    }

    // Zero-argument symbol commands: replaced with the character they
    // typeset, not a recognized-command lookup, so they need a boundary
    // check (`\ldots` isn't a prefix of some longer, unrelated command).
    const symbolCommands = {
      r'\ldots': '…',
      r'\dots': '…',
      r'\textdagger': '†',
      r'\textddagger': '‡',
      r'\dag': '†',
      r'\ddag': '‡',
      r'\textbar': '|',
      r'\textbackslash': '\\',
      r'\textasciitilde': '~',
      r'\textasciicircum': '^',
      r'\textunderscore': '_',
      r'\textbullet': '•',
      r'\textemdash': '—',
      r'\textendash': '–',
      r'\textquotedblleft': '“',
      r'\textquotedblright': '”',
      r'\textgreater': '>',
      r'\textless': '<',
      r'\S': '§',
      r'\P': '¶',
      r'\copyright': '©',
      r'\textregistered': '®',
      r'\texttrademark': '™',
      r'\LaTeX': 'LaTeX',
      r'\TeX': 'TeX',
      r'\quad': ' ',
      r'\qquad': '  ',
      r'\enspace': ' ',
      r'\thinspace': ' ',
      // \and separates \author/\keywords entries; a middle dot is how
      // multi-author headers commonly typeset it.
      r'\and': ' · ',
    };
    // \today renders the current date, like a LaTeX compile does.
    if (source.startsWith(r'\today', i) &&
        (i + 6 >= source.length || !_isAsciiLetter(source[i + 6]))) {
      run.write(_todayText());
      i += 6;
      continue;
    }
    final symbol = symbolCommands.entries
        .where(
          (e) =>
              source.startsWith(e.key, i) &&
              (i + e.key.length >= source.length ||
                  !_isAsciiLetter(source[i + e.key.length])),
        )
        .firstOrNull;
    if (symbol != null) {
      run.write(symbol.value);
      i += symbol.key.length;
      continue;
    }

    // \protect is a no-op prefix (it only matters for LaTeX's own fragile/
    // moving-argument machinery), so it's dropped and whatever follows is
    // parsed normally on the next iteration.
    if (source.startsWith(r'\protect', i) &&
        (i + 8 >= source.length || !_isAsciiLetter(source[i + 8]))) {
      i += 8;
      continue;
    }
    // \hfill is horizontal spacing with no visible content of its own.
    if (source.startsWith(r'\hfill', i) &&
        (i + 6 >= source.length || !_isAsciiLetter(source[i + 6]))) {
      i += 6;
      continue;
    }
    // \vspace{...}/\vspace*{...}/\hspace{...} are spacing; their argument
    // is a dimension, not visible content.
    final space = RegExp(r'\\[vh]space\*?').matchAsPrefix(source, i);
    if (space != null) {
      final argStart = space.end;
      final arg = argStart < source.length && source[argStart] == '{'
          ? _balancedArg(source, argStart)
          : null;
      if (arg != null) {
        // \hspace mid-sentence still separates words.
        if (source[i + 1] == 'h') run.write(' ');
        i = arg.$2;
        continue;
      }
    }

    // \verb<delim>...<delim> (and \verb*): verbatim monospace text with an
    // arbitrary one-character delimiter.
    if (source.startsWith(r'\verb', i) &&
        (i + 5 >= source.length || !_isAsciiLetter(source[i + 5]))) {
      var delimAt = i + 5;
      if (delimAt < source.length && source[delimAt] == '*') delimAt++;
      if (delimAt < source.length) {
        final close = source.indexOf(source[delimAt], delimAt + 1);
        if (close > delimAt) {
          flushRun();
          spans.add(
            TextRun(
              source.substring(delimAt + 1, close),
              bold: bold,
              italic: italic,
              monospace: true,
              underline: underline,
            ),
          );
          i = close + 1;
          continue;
        }
      }
    }

    // \symbol{code}: the character with that code ("hex, 'octal, decimal).
    if (source.startsWith(r'\symbol{', i)) {
      final arg = _balancedArg(source, i + 7);
      if (arg != null) {
        final raw = arg.$1.trim();
        final code = raw.startsWith('"')
            ? int.tryParse(raw.substring(1), radix: 16)
            : raw.startsWith("'")
            ? int.tryParse(raw.substring(1), radix: 8)
            : int.tryParse(raw);
        if (code != null && code >= 0 && code <= 0x10FFFF) {
          run.write(String.fromCharCode(code));
          i = arg.$2;
          continue;
        }
      }
    }

    // llncs's \keywords{...}: typeset as a run-in "Keywords:" line, its
    // \and separators becoming middle dots (see symbolCommands).
    if (source.startsWith(r'\keywords{', i)) {
      final arg = _balancedArg(source, i + r'\keywords'.length);
      if (arg != null) {
        flushRun();
        spans.add(const TextRun('\n'));
        spans.add(const TextRun('Keywords: ', bold: true));
        final argStart = i + r'\keywords{'.length;
        spans.addAll(
          parseInline(
            arg.$1,
            bold: bold,
            italic: italic,
            monospace: monospace,
            underline: underline,
            macros: macros,
            labels: labels,
            citations: citations,
            sourceMap: sourceMap?.sublist(argStart, argStart + arg.$1.length),
          ),
        );
        i = arg.$2;
        continue;
      }
    }

    if (source.startsWith(r'\', i)) {
      final word = RegExp(r'[a-zA-Z]+').matchAsPrefix(source, i + 1)?.group(0);
      if (word != null) {
        // \par is a paragraph break reaching inline context: a line break
        // is the closest this model gets.
        if (word == 'par') {
          flushRun();
          spans.add(const TextRun('\n'));
          i += 1 + word.length;
          continue;
        }
        // Scoped declarations (\bfseries, \ttfamily, \scriptsize, ...)
        // style the rest of the enclosing group. Bare-group recursion above
        // already bounds the scope, so applying to the remainder of this
        // source is exactly right.
        const boldDeclarations = {'bfseries', 'bf'};
        const italicDeclarations = {'itshape', 'it', 'em', 'slshape', 'sl'};
        const monospaceDeclarations = {'ttfamily', 'tt'};
        // Size and family switches this renderer doesn't model: scope-level
        // no-ops, far better than leaking the raw command.
        const inertDeclarations = {
          'rmfamily',
          'sffamily',
          'normalfont',
          'upshape',
          'mdseries',
          'scshape',
          'sc',
          'rm',
          'sf',
          'tiny',
          'scriptsize',
          'footnotesize',
          'small',
          'normalsize',
          'large',
          'Large',
          'LARGE',
          'huge',
          'Huge',
          'centering',
          'raggedright',
          'raggedleft',
        };
        final styled =
            boldDeclarations.contains(word) ||
            italicDeclarations.contains(word) ||
            monospaceDeclarations.contains(word);
        if (styled || inertDeclarations.contains(word)) {
          final restStart = i + 1 + word.length;
          if (!styled) {
            i = restStart;
            continue;
          }
          flushRun();
          spans.addAll(
            parseInline(
              source.substring(restStart),
              bold: bold || boldDeclarations.contains(word),
              italic: italic || italicDeclarations.contains(word),
              monospace: monospace || monospaceDeclarations.contains(word),
              underline: underline,
              macros: macros,
              labels: labels,
              citations: citations,
              sourceMap: sourceMap?.sublist(restStart),
            ),
          );
          i = source.length;
          continue;
        }
        // Commands that produce nothing visible, with the number of braced
        // arguments to swallow along with them.
        const droppedCommands = {
          'clearpage': 0,
          'cleardoublepage': 0,
          'newpage': 0,
          'pagebreak': 0,
          'nopagebreak': 0,
          'linebreak': 0,
          'break': 0,
          'noindent': 0,
          'indent': 0,
          'ignorespaces': 0,
          'smallskip': 0,
          'medskip': 0,
          'bigskip': 0,
          'sloppy': 0,
          'frenchspacing': 0,
          'relax': 0,
          'leavevmode': 0,
          'strut': 0,
          'vfill': 0,
          'dotfill': 0,
          'hrulefill': 0,
          'tableofcontents': 0,
          'listoffigures': 0,
          'listoftables': 0,
          'printindex': 0,
          'printglossary': 0,
          'printglossaries': 0,
          'makeindex': 0,
          'makeglossaries': 0,
          'appendix': 0,
          'footnotemark': 0,
          'qed': 0,
          'allowdisplaybreaks': 0,
          'onehalfspacing': 0,
          'singlespacing': 0,
          'doublespacing': 0,
          'pagestyle': 1,
          'thispagestyle': 1,
          'pagenumbering': 1,
          'linespread': 1,
          'captionsetup': 1,
          'markright': 1,
          'setlength': 2,
          'addtolength': 2,
          'setcounter': 2,
          'addtocounter': 2,
          'numberwithin': 2,
          'markboth': 2,
          'addcontentsline': 3,
          'bibliographystyle': 1,
          'index': 1,
          'glsadd': 1,
          'includegraphics': 1,
          // \thanks is a title-page footnote; this renderer drops it
          // rather than cluttering the centered title block.
          'thanks': 1,
          'phantom': 1,
          'hphantom': 1,
          'vphantom': 1,
          'rule': 2,
        };
        final dropArgs = droppedCommands[word];
        if (dropArgs != null) {
          var j = i + 1 + word.length;
          // An optional [...] group (e.g. \rule[raise]{w}{h}).
          var jj = _skipSpaces(source, j);
          if (jj < source.length && source[jj] == '[') {
            final close = source.indexOf(']', jj);
            if (close > 0) j = close + 1;
          }
          var ok = true;
          for (var a = 0; a < dropArgs; a++) {
            final at = _skipSpaces(source, j);
            final arg = _balancedArg(source, at);
            if (arg == null) {
              ok = false;
              break;
            }
            j = arg.$2;
          }
          if (ok) {
            i = j;
            continue;
          }
        }
      }
    }

    const styles = {
      r'\textbf{': (
        bold: true,
        italic: false,
        monospace: false,
        underline: false,
      ),
      r'\textit{': (
        bold: false,
        italic: true,
        monospace: false,
        underline: false,
      ),
      r'\emph{': (
        bold: false,
        italic: true,
        monospace: false,
        underline: false,
      ),
      // \paragraph/\subparagraph are LaTeX's smallest sectioning commands:
      // a bold run-in heading that stays on the same line as the text that
      // follows it, unlike \section and friends, so they belong here rather
      // than alongside HeadingBlock.
      r'\paragraph{': (
        bold: true,
        italic: false,
        monospace: false,
        underline: false,
      ),
      r'\subparagraph{': (
        bold: true,
        italic: false,
        monospace: false,
        underline: false,
      ),
      r'\texttt{': (
        bold: false,
        italic: false,
        monospace: true,
        underline: false,
      ),
      r'\underline{': (
        bold: false,
        italic: false,
        monospace: false,
        underline: true,
      ),
      // \gls{term}: the glossaries package's inline reference to a term
      // defined elsewhere (\newglossaryentry), which this parser doesn't
      // track. Showing the term itself, unstyled, beats leaking the raw
      // command.
      r'\gls{': (
        bold: false,
        italic: false,
        monospace: false,
        underline: false,
      ),
      // \textsuperscript{...}: shown at normal size rather than actually
      // raised — this parser's inline model has no notion of baseline
      // offset — but that beats leaking the raw command.
      r'\textsuperscript{': (
        bold: false,
        italic: false,
        monospace: false,
        underline: false,
      ),
    };
    final style = styles.entries
        .where((e) => source.startsWith(e.key, i))
        .firstOrNull;
    if (style != null) {
      final arg = _balancedArg(source, i + style.key.length - 1);
      if (arg != null) {
        flushRun();
        final argStart = i + style.key.length;
        spans.addAll(
          parseInline(
            arg.$1,
            bold: bold || style.value.bold,
            italic: italic || style.value.italic,
            monospace: monospace || style.value.monospace,
            underline: underline || style.value.underline,
            macros: macros,
            labels: labels,
            citations: citations,
            sourceMap: sourceMap?.sublist(argStart, argStart + arg.$1.length),
          ),
        );
        i = arg.$2;
        continue;
      }
    }

    // TeX ligatures: --- em dash, -- en dash, ``/'' curly double quotes,
    // ` a curly opening single quote. Typewriter fonts disable ligatures
    // in TeX, so monospace runs keep their literal characters.
    if (!monospace) {
      if (source.startsWith('---', i)) {
        run.write('—');
        i += 3;
        continue;
      }
      if (source.startsWith('--', i)) {
        run.write('–');
        i += 2;
        continue;
      }
      if (source.startsWith('``', i)) {
        run.write('“');
        i += 2;
        continue;
      }
      if (source.startsWith("''", i)) {
        run.write('”');
        i += 2;
        continue;
      }
      if (source[i] == '`') {
        run.write('‘');
        i++;
        continue;
      }
    }

    run.write(source[i]);
    i++;
  }
  flushRun();
  return spans;
}

/// "July 15, 2026" — what LaTeX's \today typesets on compile day.
String _todayText() {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final now = DateTime.now();
  return '${months[now.month - 1]} ${now.day}, ${now.year}';
}

/// Word and formula counts over parsed [blocks], for the status bar.
({int words, int formulas}) countDocument(List<DocBlock> blocks) {
  var words = 0;
  var formulas = 0;
  final wordRe = RegExp(r'\S+');
  void countSpans(List<DocInline> spans) {
    for (final span in spans) {
      switch (span) {
        case TextRun():
          words += wordRe.allMatches(span.text).length;
        case InlineMath():
          formulas++;
      }
    }
  }

  void countBlocks(List<DocBlock> blocks) {
    for (final block in blocks) {
      switch (block) {
        case TitleBlock():
          for (final metadata in [block.title, block.author, block.date]) {
            if (metadata != null) countSpans(parseInline(metadata));
          }
        case HeadingBlock():
          countSpans(block.spans);
        case ParagraphBlock():
          countSpans(block.spans);
        case DisplayMathBlock():
          formulas++;
        case ListBlock():
          block.items.forEach(countBlocks);
        case CodeBlock():
          words += wordRe.allMatches(block.code).length;
        case BibliographyBlock():
          for (final entry in block.entries) {
            countSpans(entry.spans);
          }
        case QuoteBlock():
          countBlocks(block.children);
        case TheoremBlock():
          if (block.title != null) countSpans(block.title!);
          countBlocks(block.body);
        case TableBlock():
          for (final row in block.rows) {
            for (final cell in row) {
              countSpans(cell.spans);
            }
          }
        case CenterBlock():
          countBlocks(block.children);
        case FramedBlock():
          countBlocks(block.children);
        case CaptionBlock():
          countSpans(block.spans);
        case FootnoteBlock():
          countSpans(block.spans);
        case DiagramBlock():
          break;
      }
    }
  }

  countBlocks(blocks);
  return (words: words, formulas: formulas);
}

/// Original-source index just past the construct whose stripped-text range
/// ends (exclusively) at [exclusiveEnd].
int _spanEnd(List<int> map, int exclusiveEnd) =>
    exclusiveEnd > 0 ? map[exclusiveEnd - 1] + 1 : 0;

/// The slice of [map] covering the *trimmed* content of [text]'s range
/// [start, end): one original-source index per character of
/// `text.substring(start, end).trim()`.
List<int> _trimmedSlice(List<int> map, String text, int start, int end) {
  final raw = text.substring(start, end);
  final leading = raw.length - raw.trimLeft().length;
  final trimmedLength = raw.trim().length;
  return map.sublist(start + leading, start + leading + trimmedLength);
}

/// Index of the `\end{name}` matching the `\begin{name}` whose body starts
/// at [from], skipping over same-name nested environments; -1 when
/// unterminated.
int _matchingEnvEnd(String text, String name, int from) {
  final open = '\\begin{$name}';
  final close = '\\end{$name}';
  var depth = 1;
  var i = from;
  while (i < text.length) {
    if (text.startsWith(close, i)) {
      depth--;
      if (depth == 0) return i;
      i += close.length;
    } else if (text.startsWith(open, i)) {
      depth++;
      i += open.length;
    } else {
      i++;
    }
  }
  return -1;
}

/// Rewrites CRLF/CR line endings as LF, mapping each output character back
/// to its index in [source].
({String text, List<int> map}) _normalizeLineEndings(String source) {
  final out = StringBuffer();
  final map = <int>[];
  var i = 0;
  while (i < source.length) {
    if (source[i] == '\r') {
      out.write('\n');
      map.add(i);
      i += i + 1 < source.length && source[i + 1] == '\n' ? 2 : 1;
    } else {
      out.write(source[i]);
      map.add(i);
      i++;
    }
  }
  return (text: out.toString(), map: map);
}

/// Verbatim-like environments whose body is displayed as code: `%` is a
/// literal character in there, never a comment marker.
final _verbatimEnvironmentRe = RegExp(
  r'\\(begin|end)\{(lstlisting|verbatim|Verbatim|minted)\}',
);

/// Cuts each line at its first unescaped `%` (escaped means preceded by an
/// odd number of backslashes: `\\%` IS a comment, after a line break).
/// A line that was only a comment vanishes entirely, newline included, so
/// it cannot fake the blank line that separates paragraphs (TeX's `%` eats
/// the newline too). Composes the output map from [map], which carries
/// [text]'s characters back to the original source.
///
/// Lines inside a verbatim-like environment (see [_verbatimEnvironmentRe])
/// are kept whole, `%` and all, since a code listing's own comments aren't
/// LaTeX comments.
({String text, List<int> map}) _stripComments(String text, List<int> map) {
  final out = StringBuffer();
  final outMap = <int>[];
  var first = true;
  var joinNextLine = false;
  var inVerbatim = false;
  // Index (in [text]) of the newline terminating the previous kept line;
  // the separator written before the next kept line maps back to it.
  var prevNewline = -1;
  var lineStart = 0;
  while (true) {
    final newlineIdx = text.indexOf('\n', lineStart);
    final lineEnd = newlineIdx >= 0 ? newlineIdx : text.length;
    final line = text.substring(lineStart, lineEnd);
    final verbatimMarker = _verbatimEnvironmentRe.firstMatch(line);
    final endsVerbatim = inVerbatim && verbatimMarker?.group(1) == 'end';
    var cut = -1;
    if (!inVerbatim || endsVerbatim) {
      // \url/\href/\path read their argument with verbatim-like catcodes in
      // real LaTeX: a % in there (percent-encoded URLs) is a literal
      // character, not a comment.
      final protected = <(int, int)>[];
      for (final m in RegExp(r'\\(?:url|href|path)\s*\{').allMatches(line)) {
        final arg = _balancedArg(line, m.end - 1);
        if (arg != null) protected.add((m.end, arg.$2));
      }
      for (var i = 0; i < line.length; i++) {
        if (line[i] != '%') continue;
        final at = i;
        if (protected.any((r) => at >= r.$1 && at < r.$2)) continue;
        var backslashes = 0;
        while (i - 1 - backslashes >= 0 && line[i - 1 - backslashes] == r'\') {
          backslashes++;
        }
        if (backslashes.isEven) {
          cut = i;
          break;
        }
      }
    }
    if (endsVerbatim) {
      inVerbatim = false;
    } else if (!inVerbatim && verbatimMarker?.group(1) == 'begin') {
      inVerbatim = true;
    }
    final stripped = cut < 0 ? line : line.substring(0, cut);
    final commentOnly = cut >= 0 && stripped.trim().isEmpty;
    if (!commentOnly) {
      if (!first && !joinNextLine) {
        out.write('\n');
        outMap.add(map[prevNewline]);
      }
      first = false;
      out.write(stripped);
      for (var k = 0; k < stripped.length; k++) {
        outMap.add(map[lineStart + k]);
      }
      prevNewline = lineEnd;
      joinNextLine = cut >= 0;
    }
    if (newlineIdx < 0) break;
    lineStart = newlineIdx + 1;
  }
  return (text: out.toString(), map: outMap);
}

/// When [text] starts with [open] at [at], returns the content up to the
/// matching [close] and the index just past it.
(String, int)? _delimited(String text, int at, String open, String close) {
  if (!text.startsWith(open, at)) return null;
  final start = at + open.length;
  var i = start;
  while (i < text.length) {
    // Look for the close first (it may itself start with a backslash, e.g.
    // `\]`), then skip escaped characters so `\$` never closes `$...$`.
    if (text.startsWith(close, i)) {
      return (text.substring(start, i), i + close.length);
    }
    i += text[i] == r'\' ? 2 : 1;
  }
  return null;
}

/// Reads a `{...}`-balanced argument starting at the `{` at [at]; returns the
/// content and the index just past the closing `}`.
(String, int)? _balancedArg(String text, int at) {
  if (at >= text.length || text[at] != '{') return null;
  var depth = 0;
  for (var i = at; i < text.length; i++) {
    if (text[i] == r'\') {
      i++; // skip escaped char
      continue;
    }
    if (text[i] == '{') depth++;
    if (text[i] == '}') {
      depth--;
      if (depth == 0) return (text.substring(at + 1, i), i + 1);
    }
  }
  return null;
}

/// Drops an `\item[label]` optional argument from the start of an item
/// segment, returning the remainder, how many characters were dropped, and
/// the label text itself (null when there was none).
(String, int, String?) _stripItemLabel(String segment) {
  final leading = segment.length - segment.trimLeft().length;
  final trimmed = segment.substring(leading);
  if (!trimmed.startsWith('[')) return (segment, 0, null);
  final close = trimmed.indexOf(']');
  if (close < 0) return (segment, 0, null);
  return (
    trimmed.substring(close + 1),
    leading + close + 1,
    trimmed.substring(1, close),
  );
}

/// First `\command{...}` argument in [text] (whitespace allowed before the
/// brace, and `\command` must not merely prefix a longer command), or null.
({String value, List<int> sourceMap})? _argOf(
  String text,
  List<int> sourceMap,
  String command,
) {
  final match = RegExp(
    '${RegExp.escape(command)}(?![a-zA-Z])\\s*\\{',
  ).firstMatch(text);
  if (match == null) return null;
  final argument = _balancedArg(text, match.end - 1);
  if (argument == null) return null;
  return (
    value: argument.$1,
    sourceMap: sourceMap.sublist(match.end, match.end + argument.$1.length),
  );
}

/// Occurrences of `\newcommand`, `\renewcommand`, `\providecommand`, and the
/// `\def` family that *declare* a macro, as opposed to invoking one.
final _macroDefKeyword = RegExp(
  r'\\(newcommand|renewcommand|providecommand|def|gdef|edef|xdef)(?![a-zA-Z])',
);

/// Collects every user macro declared anywhere in [source] (preamble or
/// body) into one block of `\providecommand`/`\def` statements, in source
/// order.
///
/// RaTeX's macro expander understands `\newcommand` and friends natively,
/// but [parseLatexDocument] hands each formula to RaTeX in isolation, so a
/// paper's own macros — used throughout nearly every real-world LaTeX
/// document — would otherwise report as "Undefined control sequence" on
/// every formula that uses them. Prepending this block to a formula before
/// rendering (see `document_view.dart` and `formula_check.dart`) lets those
/// macros resolve the same way they would in a full LaTeX run.
///
/// `\newcommand`/`\renewcommand` are rewritten to `\providecommand`, which
/// RaTeX accepts whether or not the name is already defined. Left as-is, a
/// `\newcommand` that happens to collide with a RaTeX builtin, or a
/// `\renewcommand` for a name RaTeX never predefined, would throw and take
/// every later formula down with it, since all formulas share one prelude.
String extractMacroPreamble(String source) {
  final normalized = _normalizeLineEndings(source);
  final text = _stripComments(normalized.text, normalized.map).text;

  final definitions = StringBuffer();
  for (final match in _macroDefKeyword.allMatches(text)) {
    final keyword = match.group(1)!;
    final end = keyword.endsWith('def')
        ? _readDefEnd(text, match.end)
        : _readNewcommandEnd(text, match.end);
    if (end == null) continue;
    final rewritten = keyword == 'newcommand' || keyword == 'renewcommand'
        ? r'\providecommand'
        : '\\$keyword';
    definitions
      ..write(rewritten)
      ..write(text.substring(match.end, end))
      ..write('\n');
  }
  return definitions.toString();
}

/// Index just past a `\newcommand`-family declaration's body, given [from]
/// just after the keyword (`\newcommand`, `\renewcommand`, ...); null when
/// the declaration is too malformed to safely extract.
int? _readNewcommandEnd(String text, int from) {
  var i = _skipSpaces(text, from);
  if (i < text.length && text[i] == '*') i = _skipSpaces(text, i + 1);
  final afterName = _readMacroName(text, i);
  if (afterName == null) return null;
  i = _skipSpaces(text, afterName);
  // Up to two optional `[...]` groups: argument count and a default value
  // for the first argument.
  for (var group = 0; group < 2 && i < text.length && text[i] == '['; group++) {
    final close = text.indexOf(']', i);
    if (close < 0) return null;
    i = _skipSpaces(text, close + 1);
  }
  if (i >= text.length || text[i] != '{') return null;
  return _balancedArg(text, i)?.$2;
}

/// Index just past a `\def`-family declaration's body, given [from] just
/// after the keyword; null when the declaration is too malformed to safely
/// extract.
int? _readDefEnd(String text, int from) {
  final afterName = _readMacroName(
    text,
    _skipSpaces(text, from),
    allowGroup: false,
  );
  if (afterName == null) return null;
  // Parameter text (`#1#2...`, or delimiter tokens) runs up to the body's
  // opening brace; TeX doesn't allow an unescaped `{` inside it.
  var i = afterName;
  while (i < text.length && text[i] != '{') {
    i += text[i] == r'\' ? 2 : 1;
  }
  if (i >= text.length) return null;
  return _balancedArg(text, i)?.$2;
}

/// Consumes the macro name a declaration binds: either a `{...}`-wrapped
/// name (`\newcommand{\foo}`) or a single control sequence
/// (`\newcommand\foo`, always the case for `\def`). Returns the index just
/// past it, or null if [at] isn't the start of either form.
int? _readMacroName(String text, int at, {bool allowGroup = true}) {
  if (allowGroup && at < text.length && text[at] == '{') {
    return _balancedArg(text, at)?.$2;
  }
  if (at >= text.length || text[at] != r'\') return null;
  var i = at + 1;
  if (i < text.length && _isAsciiLetter(text[i])) {
    while (i < text.length && _isAsciiLetter(text[i])) {
      i++;
    }
  } else if (i < text.length) {
    i++; // A single-character control symbol, e.g. `\@`.
  }
  return i;
}

bool _isAsciiLetter(String ch) {
  final code = ch.codeUnitAt(0);
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
}

/// Single-symbol TeX accent commands (`\'e`, `\"{u}`, ...), mapped to the
/// Unicode combining mark that reproduces them.
const _accentSymbolMarks = {
  '`': '̀', // grave
  "'": '́', // acute
  '^': '̂', // circumflex
  '"': '̈', // diaeresis/umlaut
  '~': '̃', // tilde
  '=': '̄', // macron
  '.': '̇', // dot above
};

/// Letter-named TeX accent commands (`\c{c}`, `\v{s}`, ...), which (unlike
/// the symbol ones above) always take a braced argument — otherwise `\v`
/// couldn't be told apart from the start of `\vspace`.
const _accentLetterMarks = {
  'c': '̧', // cedilla
  'v': '̌', // caron
  'H': '̋', // double acute
  'k': '̨', // ogonek
  'r': '̊', // ring above
  'd': '̣', // dot below
  'u': '̆', // breve
  'b': '̱', // macron below
};

/// The text an accent command applies to: `{...}`-wrapped (`\"{u}`) or a
/// single bare character (`\"u`). Declining a nested command (`\"{\i}`,
/// LaTeX's dotless-i idiom) rather than guessing at it keeps this honest —
/// the accent command is left as literal text instead.
(String, int)? _accentBase(String source, int at) {
  if (at >= source.length) return null;
  if (source[at] == '{') {
    final arg = _balancedArg(source, at);
    if (arg == null || arg.$1.isEmpty || arg.$1.startsWith(r'\')) return null;
    return (arg.$1, arg.$2);
  }
  return _isAsciiLetter(source[at]) ? (source[at], at + 1) : null;
}

int _skipSpaces(String text, int at) {
  var i = at;
  while (i < text.length &&
      (text[i] == ' ' || text[i] == '\t' || text[i] == '\n')) {
    i++;
  }
  return i;
}

/// A parsed `\newcommand`/`\def`-family declaration, kept structured (as
/// opposed to [extractMacroPreamble]'s flat text) so [_expandTextMacros] can
/// substitute `#1`..`#9` itself.
class MacroDefinition {
  const MacroDefinition(this.name, this.argCount, this.body);

  /// Without the leading backslash.
  final String name;
  final int argCount;
  final String body;
}

/// Every macro declared anywhere in [text] (already comment-stripped), in
/// source order — later declarations of the same name win, matching how
/// [extractMacroPreamble] normalizes redefinition to `\providecommand`.
Map<String, MacroDefinition> _parseMacroDefs(String text) {
  final defs = <String, MacroDefinition>{};
  for (final match in _macroDefKeyword.allMatches(text)) {
    final keyword = match.group(1)!;
    final def = keyword.endsWith('def')
        ? _parseDefDeclaration(text, match.end)
        : _parseNewcommandDeclaration(text, match.end);
    if (def != null) defs[def.name] = def;
  }
  return defs;
}

MacroDefinition? _parseNewcommandDeclaration(String text, int from) {
  var i = _skipSpaces(text, from);
  if (i < text.length && text[i] == '*') i = _skipSpaces(text, i + 1);
  final name = _readMacroNameSpan(text, i);
  if (name == null) return null;
  i = _skipSpaces(text, name.$2);
  var argCount = 0;
  for (var group = 0; group < 2 && i < text.length && text[i] == '['; group++) {
    final close = text.indexOf(']', i);
    if (close < 0) return null;
    if (group == 0) {
      argCount = int.tryParse(text.substring(i + 1, close).trim()) ?? 0;
    }
    i = _skipSpaces(text, close + 1);
  }
  if (i >= text.length || text[i] != '{') return null;
  final body = _balancedArg(text, i);
  return body == null ? null : MacroDefinition(name.$1, argCount, body.$1);
}

MacroDefinition? _parseDefDeclaration(String text, int from) {
  final name = _readMacroNameSpan(
    text,
    _skipSpaces(text, from),
    allowGroup: false,
  );
  if (name == null) return null;
  var i = name.$2;
  var argCount = 0;
  while (i < text.length && text[i] != '{') {
    if (text[i] == '#') argCount++;
    i += text[i] == r'\' ? 2 : 1;
  }
  if (i >= text.length) return null;
  final body = _balancedArg(text, i);
  return body == null ? null : MacroDefinition(name.$1, argCount, body.$1);
}

/// Like [_readMacroName], but also returns the name itself (without its
/// leading backslash).
(String, int)? _readMacroNameSpan(
  String text,
  int at, {
  bool allowGroup = true,
}) {
  if (allowGroup && at < text.length && text[at] == '{') {
    final arg = _balancedArg(text, at);
    if (arg == null) return null;
    final raw = arg.$1.trim();
    return (raw.startsWith(r'\') ? raw.substring(1) : raw, arg.$2);
  }
  final end = _readMacroName(text, at, allowGroup: false);
  return end == null ? null : (text.substring(at + 1, end), end);
}

/// Expands custom macros in plain prose text — [extractMacroPreamble]
/// covers macros used *inside* math (RaTeX's own expander handles those
/// natively), but text outside of math needs its own, simpler pass: a
/// paper's own shorthand (`\fn{name}`, `\ghlink{path}{text}`, and the like)
/// is common in real-world LaTeX and would otherwise show up as raw source.
///
/// This is intentionally not a full TeX macro engine: no delimited
/// parameters, no conditionals, no expansion inside an argument before it's
/// substituted. Bounded recursion (macros expanding to other macros) keeps
/// a definition cycle from looping forever.
String _expandTextMacros(
  String text,
  Map<String, MacroDefinition> macros, [
  int depth = 0,
]) {
  if (macros.isEmpty || depth > 8 || !text.contains(r'\')) return text;
  final out = StringBuffer();
  var i = 0;
  var changed = false;
  // True immediately after writing an unexpanded control word (`\foo`, left
  // as-is because it isn't one of [macros]) or a macro expansion whose body
  // itself ends in one. Naive string concatenation loses TeX's token
  // boundaries: real TeX keeps a macro's expansion as tokens distinct from
  // whatever preceded it, but re-lexing the concatenated *text* would merge
  // a following letter into that control word (`\to` + an expansion of "b"
  // reads back as the single, undefined control word `\tob`). An empty
  // group after the control word blocks that merge without changing what
  // it means.
  var afterBareControlWord = false;
  while (i < text.length) {
    if (text[i] != r'\') {
      out.write(text[i]);
      afterBareControlWord = false;
      i++;
      continue;
    }
    final name = RegExp(r'[a-zA-Z]+').matchAsPrefix(text, i + 1)?.group(0);
    final macro = name == null ? null : macros[name];
    if (macro == null) {
      // Not a declared macro (a control symbol like `\%`, or a real
      // KaTeX/RaTeX command): copy the whole control word verbatim.
      final end = name == null ? i + 1 : i + 1 + name.length;
      out.write(text.substring(i, end));
      afterBareControlWord = name != null;
      i = end;
      continue;
    }
    var j = i + 1 + name!.length;
    final args = <String>[];
    for (var a = 0; a < macro.argCount; a++) {
      j = _skipSpaces(text, j);
      final arg = j < text.length && text[j] == '{'
          ? _balancedArg(text, j)
          : null;
      if (arg == null) break;
      args.add(arg.$1);
      j = arg.$2;
    }
    if (args.length != macro.argCount) {
      // A required argument is missing (e.g. `\foo` used with no braces
      // where `\foo` needs one): leave the name as literal text rather
      // than guessing.
      out.write(r'\');
      out.write(name);
      afterBareControlWord = true;
      i += 1 + name.length;
      continue;
    }
    // A single pass over the original body, substituting #1..#9 from
    // [args]: sequential replaceAll calls would risk re-matching a "#N"
    // that an earlier substitution's own argument value happened to
    // contain.
    final body = macro.body.replaceAllMapped(RegExp(r'#([1-9])'), (m) {
      final index = int.parse(m.group(1)!) - 1;
      return index < args.length ? args[index] : m.group(0)!;
    });
    if (afterBareControlWord && body.isNotEmpty && _isAsciiLetter(body[0])) {
      out.write('{}');
    }
    out.write(body);
    afterBareControlWord = RegExp(r'\\[a-zA-Z]+$').hasMatch(body);
    i = j;
    changed = true;
  }
  final result = out.toString();
  return changed ? _expandTextMacros(result, macros, depth + 1) : result;
}
