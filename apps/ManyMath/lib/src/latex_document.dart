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

final class ListBlock extends DocBlock {
  const ListBlock({required this.ordered, required this.items});

  final bool ordered;
  final List<List<DocInline>> items;
}

/// One run of inline content inside a paragraph, heading, or list item.
sealed class DocInline {
  const DocInline();
}

final class TextRun extends DocInline {
  const TextRun(this.text, {this.bold = false, this.italic = false});

  final String text;
  final bool bold;
  final bool italic;
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
    final spans = parseInline(
      content,
      sourceMap: map.sublist(start, start + content.length),
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
        if (name == 'itemize' || name == 'enumerate') {
          flushParagraph();
          // \item only, not \itemsep and friends. Nested block content
          // inside an item degrades to inline text (see parseInline), but
          // the depth-aware end search above keeps it inside the item
          // instead of leaking raw \end tokens into the page. Content
          // before the first \item (typically spacing commands like
          // \itemsep0pt) is not a bullet.
          final marks = RegExp(r'\\item(?![a-zA-Z])').allMatches(body).toList();
          final items = <List<DocInline>>[];
          for (var k = 0; k < marks.length; k++) {
            final segStart = marks[k].end;
            final segEnd = k + 1 < marks.length
                ? marks[k + 1].start
                : body.length;
            final label = _stripItemLabel(body.substring(segStart, segEnd));
            final segment = label.$1;
            final leading = segment.length - segment.trimLeft().length;
            final trimmed = segment.trim();
            if (trimmed.isEmpty) continue;
            final start = env.end + segStart + label.$2 + leading;
            items.add(
              parseInline(
                trimmed,
                sourceMap: map.sublist(start, start + trimmed.length),
              ),
            );
          }
          if (items.isNotEmpty) {
            blocks.add(ListBlock(ordered: name == 'enumerate', items: items));
          }
          i = next;
          continue;
        }
      }
      // Unknown or unterminated environment: fall through as text.
    }

    // Sections and \maketitle, recognized at any position.
    final section = RegExp(r'\\(sub){0,2}section\*?\{').matchAsPrefix(text, i);
    if (section != null) {
      final arg = _balancedArg(text, section.end - 1);
      if (arg != null) {
        flushParagraph();
        final level = 'sub'.allMatches(section[0]!).length + 1;
        blocks.add(
          HeadingBlock(
            level,
            parseInline(
              arg.$1,
              sourceMap: map.sublist(section.end, section.end + arg.$1.length),
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
  List<int>? sourceMap,
}) {
  assert(
    sourceMap == null || sourceMap.length == source.length,
    'sourceMap must align 1:1 with source',
  );
  final spans = <DocInline>[];
  final run = StringBuffer();

  void flushRun() {
    if (run.isEmpty) return;
    final content = run.toString();
    run.clear();
    // Collapse whitespace runs (LaTeX treats newlines as spaces).
    final collapsed = content.replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isNotEmpty) {
      spans.add(TextRun(collapsed, bold: bold, italic: italic));
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

    const styles = {
      r'\textbf{': (bold: true, italic: false),
      r'\textit{': (bold: false, italic: true),
      r'\emph{': (bold: false, italic: true),
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
            sourceMap: sourceMap?.sublist(argStart, argStart + arg.$1.length),
          ),
        );
        i = arg.$2;
        continue;
      }
    }

    run.write(source[i]);
    i++;
  }
  flushRun();
  return spans;
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
        block.items.forEach(countSpans);
    }
  }
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

/// Cuts each line at its first unescaped `%` (escaped means preceded by an
/// odd number of backslashes: `\\%` IS a comment, after a line break).
/// A line that was only a comment vanishes entirely, newline included, so
/// it cannot fake the blank line that separates paragraphs (TeX's `%` eats
/// the newline too). Composes the output map from [map], which carries
/// [text]'s characters back to the original source.
({String text, List<int> map}) _stripComments(String text, List<int> map) {
  final out = StringBuffer();
  final outMap = <int>[];
  var first = true;
  var joinNextLine = false;
  // Index (in [text]) of the newline terminating the previous kept line;
  // the separator written before the next kept line maps back to it.
  var prevNewline = -1;
  var lineStart = 0;
  while (true) {
    final newlineIdx = text.indexOf('\n', lineStart);
    final lineEnd = newlineIdx >= 0 ? newlineIdx : text.length;
    final line = text.substring(lineStart, lineEnd);
    var cut = -1;
    for (var i = 0; i < line.length; i++) {
      if (line[i] != '%') continue;
      var backslashes = 0;
      while (i - 1 - backslashes >= 0 && line[i - 1 - backslashes] == r'\') {
        backslashes++;
      }
      if (backslashes.isEven) {
        cut = i;
        break;
      }
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
/// segment, returning the remainder and how many characters were dropped.
(String, int) _stripItemLabel(String segment) {
  final leading = segment.length - segment.trimLeft().length;
  final trimmed = segment.substring(leading);
  if (!trimmed.startsWith('[')) return (segment, 0);
  final close = trimmed.indexOf(']');
  if (close < 0) return (segment, 0);
  return (trimmed.substring(close + 1), leading + close + 1);
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
