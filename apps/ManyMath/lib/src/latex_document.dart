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
  final List<List<DocInline>> items;
}

/// A verbatim-like environment (`lstlisting`, `verbatim`, `Verbatim`,
/// `minted`): shown as preformatted monospace text, with no macro or math
/// interpretation of its contents.
final class CodeBlock extends DocBlock {
  const CodeBlock(this.code);

  final String code;
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
  // \begin{document} slice below drops it) so preamble-declared macros are
  // seen; see _expandTextMacros.
  final macros = _parseMacroDefs(stripped.text);

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
      macros: macros,
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
        if (name == 'itemize' || name == 'enumerate' || name == 'description') {
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
            if (trimmed.isEmpty && label.$3 == null) continue;
            final start = env.end + segStart + label.$2 + leading;
            final itemSpans = parseInline(
              trimmed,
              macros: macros,
              sourceMap: map.sublist(start, start + trimmed.length),
            );
            // \description's `[label]` is the item's required title, not an
            // optional override like itemize/enumerate's, so it's shown
            // (bolded) instead of being dropped.
            items.add(
              name == 'description' && label.$3 != null
                  ? [
                      TextRun(label.$3!.trim(), bold: true),
                      const TextRun(' '),
                      ...itemSpans,
                    ]
                  : itemSpans,
            );
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
              macros: macros,
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
  bool monospace = false,
  bool underline = false,
  Map<String, MacroDefinition> macros = const {},
  List<int>? sourceMap,
}) {
  assert(
    sourceMap == null || sourceMap.length == source.length,
    'sourceMap must align 1:1 with source',
  );
  if (macros.isNotEmpty) {
    final expanded = _expandTextMacros(source, macros);
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
    // \url's argument is verbatim (LaTeX doesn't interpret `_`, `%`, etc.
    // inside it), so it's taken as-is rather than recursively parsed.
    if (source.startsWith(r'\url{', i)) {
      final arg = _balancedArg(source, i + r'\url'.length);
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

    const styles = {
      r'\textbf{': (bold: true, italic: false, monospace: false, underline: false),
      r'\textit{': (bold: false, italic: true, monospace: false, underline: false),
      r'\emph{': (bold: false, italic: true, monospace: false, underline: false),
      // \paragraph/\subparagraph are LaTeX's smallest sectioning commands:
      // a bold run-in heading that stays on the same line as the text that
      // follows it, unlike \section and friends, so they belong here rather
      // than alongside HeadingBlock.
      r'\paragraph{': (bold: true, italic: false, monospace: false, underline: false),
      r'\subparagraph{': (bold: true, italic: false, monospace: false, underline: false),
      r'\texttt{': (bold: false, italic: false, monospace: true, underline: false),
      r'\underline{': (bold: false, italic: false, monospace: false, underline: true),
      // \gls{term}: the glossaries package's inline reference to a term
      // defined elsewhere (\newglossaryentry), which this parser doesn't
      // track. Showing the term itself, unstyled, beats leaking the raw
      // command.
      r'\gls{': (bold: false, italic: false, monospace: false, underline: false),
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
      case CodeBlock():
        words += wordRe.allMatches(block.code).length;
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
  final afterName = _readMacroName(text, _skipSpaces(text, from), allowGroup: false);
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
  final name = _readMacroNameSpan(text, _skipSpaces(text, from), allowGroup: false);
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
(String, int)? _readMacroNameSpan(String text, int at, {bool allowGroup = true}) {
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
String _expandTextMacros(String text, Map<String, MacroDefinition> macros, [int depth = 0]) {
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
      final arg = j < text.length && text[j] == '{' ? _balancedArg(text, j) : null;
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
