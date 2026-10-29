/// Extracts problem items (exercises with their answers, theorems,
/// propositions, worked examples) from a parsed LaTeX document, for the math
/// game's problem bank.
///
/// This reads the parser's block stream rather than the raw source, so it
/// inherits the parser's environment support: `Problems` and `Examples`
/// bodies, `\Item{(n)}` numbering, `Answers` (which the parser announces with
/// an "Exercise N" heading), `SubProbs`, and theorem-like environments.
/// Pure Dart, so the export tool runs on the plain VM.
library;

import 'latex_document.dart';

/// One exportable item.
class ProblemItem {
  ProblemItem({
    required this.id,
    required this.book,
    required this.section,
    required this.number,
    required this.kind,
    required this.statementTex,
    required this.formulas,
    required this.file,
    required this.line,
  });

  final String id;
  final String book;
  final String section;
  final String number;

  /// `exercise`, `theorem`, `proposition`, or `example`.
  final String kind;
  final String statementTex;
  String? answerTex;
  final List<String> formulas;
  final String file;
  final int line;

  Map<String, Object?> toJson() => {
    'id': id,
    'book': book,
    'section': section,
    'number': number,
    'kind': kind,
    'statement_tex': statementTex,
    'answer_tex': answerTex,
    'formulas': formulas,
    'source': {'file': file, 'line': line},
  };
}

/// What [extractProblems] found, with the figures worth reporting.
class ProblemExport {
  ProblemExport(
    this.items, {
    required this.answers,
    required this.unmatched,
    this.warnings = const [],
  });

  final List<ProblemItem> items;

  /// Answer items read from `Answers` blocks, and how many of them had no
  /// exercise with the same set and number to attach to.
  final int answers;
  final int unmatched;

  /// Things that look wrong: an id or an answer key that occurred more than
  /// once (ids are made unique with a numeric suffix, so nothing is lost, but
  /// the repeat usually means a set was not delimited properly).
  final List<String> warnings;
}

/// Sentinel bold runs the extractor inserts around `Problems`, `Examples` and
/// `Answers` bodies, so a set ends with its environment rather than with the
/// next section heading.
const _beginMark = 'ExportSetBoundaryBegin';
const _endMark = 'ExportSetBoundaryEnd';

/// Inserted before `\Paragraph{`: a numbered paragraph ends a set that has
/// already started listing items (its own `\Item{1.}` worked examples are not
/// exercises).
const _breakMark = 'ExportSetBoundaryBreak';

/// Replaces an inline `\Ans{...}` (the printed answer of a worked-in-text
/// exercise); the number after it indexes the answers kept aside.
const _inlineAnsMark = 'ExportInlineAns';

final _setEnv = RegExp(
  r'\\(begin|end)\{(?:Problems|Examples|Answers)\}|(\\Paragraph)\{|(\\Answers)\b|(\\Ans)\{',
);
final _hfilNumber = RegExp(r'\\hfil\s*\((\d+)\)\s*');
final _inlineAnswer = RegExp(
  r'^\s*\\text\{\s*\\textit\{Ans\.\}(.*)\}\s*$',
  dotAll: true,
);

final _heading = RegExp(r'^(Exercises?|Problems?|Examples?)\b\s*(.*)$');
final _itemNumber = RegExp(r'^\(?(\d+[a-z]?)\)?\.?$');

enum _Mode { none, exercises, answers, examples }

/// An item being collected: its LaTeX so far, formulas, and where it began.
class _Draft {
  _Draft(this.number, this.fallbackLine);

  final String number;
  final int fallbackLine;
  int? offset;
  final text = StringBuffer();
  final formulas = <String>[];

  /// An `Ans.` line printed inside the statement itself, set aside.
  String? inlineAnswer;
  final inlineFormulas = <String>[];

  String get tex => text
      .toString()
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r' ?\n ?'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  void math(String latex, int? at, {required bool display}) {
    formulas.add(latex);
    offset ??= at;
    text.write(
      display && !latex.startsWith(r'\begin') ? '\\[$latex\\]' : '\$$latex\$',
    );
    if (display) text.write('\n\n');
  }

  void spans(List<DocInline> spans) {
    for (final s in spans) {
      switch (s) {
        case TextRun t:
          text.write(t.text);
        case InlineMath m:
          formulas.add(m.latex);
          offset ??= m.sourceStart;
          text.write('\$${m.latex}\$');
      }
    }
  }

  /// Appends [blocks] (a theorem body, list items, a frame) as LaTeX.
  void blocks(List<DocBlock> blocks) {
    for (final b in blocks) {
      switch (b) {
        case ParagraphBlock p:
          spans(p.spans);
          text.write('\n\n');
        case DisplayMathBlock d:
          math(d.latex, d.sourceStart, display: true);
        case ListBlock l:
          l.items.forEach(this.blocks);
        case TheoremBlock t:
          this.blocks(t.body);
        case FramedBlock f:
          this.blocks(f.children);
        case CenterBlock c:
          this.blocks(c.children);
        default:
          break;
      }
    }
  }
}

/// The sentinel [p] carries, if it is one of the set-boundary markers.
String? _markOf(ParagraphBlock p) {
  if (p.spans.length != 1) return null;
  final s = p.spans.first;
  if (s is! TextRun || !s.bold) return null;
  final text = s.text.trim();
  return text == _beginMark || text == _endMark || text == _breakMark
      ? text
      : null;
}

String _plain(List<DocInline> spans) => spans
    .map(
      (s) => switch (s) {
        TextRun t => t.text,
        InlineMath m => m.latex,
      },
    )
    .join();

/// Wentworth-style back-of-book answers: `\Answers` opens the section and each
/// `\AnsTo[cols]{Exercise}{N.}` heads a list of `\Item{k.}` answers. Returns
/// answers by `N#k` in book order, so a number repeated within one exercise
/// keeps every answer.
Map<String, List<_Draft>> _parseAnsToAnswers(String source) {
  final result = <String, List<_Draft>>{};
  final start = source.indexOf('\\Answers\n');
  if (start == -1) return result;
  var section = source.substring(start);
  final gutenberg = RegExp(
    r'End of (?:the )?Project Gutenberg',
  ).firstMatch(section);
  if (gutenberg != null) section = section.substring(0, gutenberg.start);
  final heads = RegExp(
    r'\\AnsTo(?:\[\d+\])?\{Exercise\}\{(\d+)\.\}',
  ).allMatches(section).toList();
  final itemRe = RegExp(r'\\Item\{(\d+)\.\}');
  for (var k = 0; k < heads.length; k++) {
    final end = k + 1 < heads.length ? heads[k + 1].start : section.length;
    var body = section.substring(heads[k].end, end);
    final doc = body.indexOf(RegExp(r'\\end\{document\}|\\BackMatter'));
    if (doc != -1) body = body.substring(0, doc);
    body = body
        .replaceAll(RegExp(r'(?<!\\)%[^\n]*'), '')
        .replaceAll(RegExp(r'\\ResetCols(?:\[\d+\])?'), ' ')
        .replaceAll(RegExp(r'\\(?:begin|end)\{multicols\}(?:\{\d+\})?'), ' ');
    final marks = itemRe.allMatches(body).toList();
    for (var i = 0; i < marks.length; i++) {
      final stop = i + 1 < marks.length ? marks[i + 1].start : body.length;
      final d = _Draft(marks[i].group(1)!, 1)
        ..text.write(body.substring(marks[i].end, stop));
      for (final m in RegExp(r'\$([^\$]+)\$').allMatches(d.tex)) {
        d.formulas.add(m.group(1)!);
      }
      if (d.tex.isEmpty) continue;
      result
          .putIfAbsent('${heads[k].group(1)}#${marks[i].group(1)}', () => [])
          .add(d);
    }
  }
  return result;
}

/// Parses [source] and returns its problem items. [file] and [book] label the
/// output; [book] defaults to the file name without its extension.
ProblemExport extractProblems(String source, {String file = '', String? book}) {
  // Mark where each set environment begins and ends. The markers shift later
  // offsets, so `original` maps a parsed offset back to the given source.
  final marked = StringBuffer();
  // (offset in marked text, inserted length, removed length)
  final shifts = <(int, int, int)>[];
  final inlineAnswers = <String>[];
  var copied = 0;
  for (final m in _setEnv.allMatches(source)) {
    if (m.start < copied) continue;
    if (m.group(4) != null) {
      var depth = 1;
      var end = m.end;
      while (end < source.length && depth > 0) {
        final c = source[end++];
        if (c == '\\') {
          end++;
        } else if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
        }
      }
      final text = '\n\n\\textbf{$_inlineAnsMark${inlineAnswers.length}}\n\n';
      inlineAnswers.add(source.substring(m.end, end - 1).trim());
      marked.write(source.substring(copied, m.start));
      shifts.add((marked.length, text.length, end - m.start));
      marked.write(text);
      copied = end;
      continue;
    }
    final mark = m.group(2) != null
        ? _breakMark
        : m.group(3) != null
        ? _endMark
        : m.group(1) == 'begin'
        ? _beginMark
        : _endMark;
    final text = '\n\n\\textbf{$mark}\n\n';
    marked.write(source.substring(copied, m.start));
    shifts.add((marked.length, text.length, 0));
    marked.write(text);
    copied = m.start;
  }
  marked.write(source.substring(copied));
  int original(int offset) {
    var shift = 0;
    for (final (at, len, removed) in shifts) {
      if (offset < at) break;
      shift += offset < at + len ? offset - at : len - removed;
    }
    return offset - shift;
  }

  final ansTo = _parseAnsToAnswers(source);
  final ansToUsed = <String, int>{};
  final blocks = parseLatexDocument(marked.toString());
  final bookName = book ?? _bookFromFile(file);
  final lineStarts = <int>[0];
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 10) lineStarts.add(i + 1);
  }
  int lineOf(int offset) {
    var lo = 0;
    var hi = lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo + 1;
  }

  final items = <ProblemItem>[];
  final itemKeys = <ProblemItem, String>{};
  final answers = <String, _Draft>{};
  var mode = _Mode.none;
  var inSet = false;
  var itemsInSet = 0;
  final warnings = <String>[];
  final seenIds = <String, int>{};
  final inline = <ProblemItem, _Draft>{};
  var section = '';
  var setLabel = '';
  var lastLine = 1;
  _Draft? draft;
  var theoremCount = 0;

  int lineFor(_Draft d) {
    final at = d.offset;
    if (at == null) return d.fallbackLine;
    return lastLine = lineOf(original(at));
  }

  String uniqueId(String base) {
    final n = (seenIds[base] ?? 0) + 1;
    seenIds[base] = n;
    if (n == 1) return base;
    warnings.add('repeated id $base (occurrence $n)');
    return '${base}_$n';
  }

  void flush() {
    final d = draft;
    draft = null;
    if (d == null || (d.tex.isEmpty && d.formulas.isEmpty)) return;
    final line = lineFor(d);
    if (mode == _Mode.answers) {
      final key = '$setLabel#${d.number}';
      if (answers.containsKey(key)) {
        warnings.add('repeated answer key $key at line $line');
      } else {
        answers[key] = d;
      }
      return;
    }
    final kind = mode == _Mode.examples ? 'example' : 'exercise';
    final item = ProblemItem(
      id: uniqueId(_slug('${bookName}_${setLabel}_${d.number}_$kind')),
      book: bookName,
      section: section,
      number: d.number,
      kind: kind,
      statementTex: d.tex,
      formulas: d.formulas,
      file: file,
      line: line,
    );
    items.add(item);
    itemKeys[item] = '$setLabel#${d.number}';
    if (d.inlineAnswer != null) inline[item] = d;
  }

  void paragraph(ParagraphBlock p) {
    draft?.text.write('\n\n');
    for (var s in p.spans) {
      // Answers sometimes run on a line: `... \hfil (12)~...`.
      if (mode == _Mode.answers && s is TextRun && !s.bold) {
        final parts = s.text.split(_hfilNumber);
        if (parts.length > 1) {
          final numbers = _hfilNumber
              .allMatches(s.text)
              .map((m) => m.group(1)!)
              .toList();
          draft?.text.write(parts.first);
          for (var i = 0; i < numbers.length; i++) {
            flush();
            draft = _Draft(numbers[i], lastLine);
            draft?.text.write(parts[i + 1]);
          }
          continue;
        }
      }
      // `\Item{(n)}` comes through as a bold run holding just the number.
      final marker = s is TextRun && s.bold
          ? _itemNumber.firstMatch(s.text.trim())
          : null;
      if (s is TextRun && s.bold && s.text.trim().startsWith(_inlineAnsMark)) {
        final d = draft;
        if (mode == _Mode.exercises && d != null) {
          final text =
              inlineAnswers[int.parse(
                s.text.trim().substring(_inlineAnsMark.length),
              )];
          d.inlineAnswer = text;
          for (final m in RegExp(r'\$([^\$]+)\$').allMatches(text)) {
            d.inlineFormulas.add(m.group(1)!);
          }
        }
      } else if (marker != null) {
        flush();
        draft = _Draft(marker.group(1)!, lastLine);
        itemsInSet++;
      } else {
        draft?.spans([s]);
      }
    }
  }

  void heading(HeadingBlock h) {
    flush();
    final text = _plain(h.spans).trim();
    final m = _heading.firstMatch(text);
    if (m != null && h.level >= 2) {
      final isExamples = m.group(1)!.startsWith('Example');
      // The parser announces an `Answers` block as an H3 titled
      // "Exercise <set> — ...".
      if (h.level == 3 && !isExamples && !m.group(1)!.endsWith('s')) {
        mode = _Mode.answers;
      } else {
        mode = isExamples ? _Mode.examples : _Mode.exercises;
      }
      setLabel = m.group(2)!.split(RegExp(r'\s+[—–-]\s+')).first.trim();
      section = isExamples ? text : 'Exercises $setLabel'.trim();
      inSet = true;
      itemsInSet = 0;
    } else if (h.level <= 2) {
      // A heading between a set's opening and its first item (a
      // "Miscellaneous" title) names the set; after that it ends it.
      if (inSet && itemsInSet == 0) return;
      inSet = false;
      mode = _Mode.none;
      setLabel = '';
      section = text;
    }
  }

  void theorem(TheoremBlock t) {
    flush();
    final kind = _theoremKind(t.noun);
    if (kind == null) return;
    theoremCount++;
    final d = _Draft(t.number ?? '$theoremCount', lastLine)..blocks(t.body);
    if (d.tex.isEmpty) return;
    items.add(
      ProblemItem(
        id: uniqueId(_slug('${bookName}_${t.noun}_${d.number}')),
        book: bookName,
        section: section,
        number: d.number,
        kind: kind,
        statementTex: d.tex,
        formulas: d.formulas,
        file: file,
        line: lineFor(d),
      ),
    );
  }

  void walk(List<DocBlock> list) {
    for (final b in list) {
      switch (b) {
        case HeadingBlock h:
          heading(h);
        case ParagraphBlock p when _markOf(p) != null:
          final mark = _markOf(p);
          if (mark == _beginMark) {
            flush();
            inSet = true;
            itemsInSet = 0;
          } else if (mark == _endMark || itemsInSet > 0) {
            flush();
            inSet = false;
          }
        case ParagraphBlock p when mode != _Mode.none && inSet:
          paragraph(p);
        case DisplayMathBlock d when mode != _Mode.none && inSet:
          final ans = mode == _Mode.exercises
              ? _inlineAnswer.firstMatch(d.latex)
              : null;
          if (ans != null && draft != null) {
            draft!.inlineAnswer = ans.group(1)!.trim();
            draft!.offset ??= d.sourceStart;
            for (final m in RegExp(r'\$([^\$]+)\$').allMatches(ans.group(1)!)) {
              draft!.inlineFormulas.add(m.group(1)!);
            }
          } else {
            draft?.math(d.latex, d.sourceStart, display: true);
          }
        case ListBlock l when mode != _Mode.none && inSet:
          l.items.forEach(draft?.blocks ?? (_) {});
        case TheoremBlock t:
          theorem(t);
        case FramedBlock f:
          walk(f.children);
        case CenterBlock c:
          walk(c.children);
        default:
          break;
      }
    }
  }

  walk(blocks);
  flush();

  var matched = 0;
  for (final item in items) {
    final digits = RegExp(
      r'^(\d+)',
    ).firstMatch(itemKeys[item]?.split('#').first ?? '');
    final key =
        '${digits?.group(1)}#${RegExp(r'^\d+').firstMatch(item.number)?.group(0)}';
    final queue = item.kind == 'exercise' ? ansTo[key] : null;
    final used = ansToUsed[key] ?? 0;
    if (queue != null) ansToUsed[key] = used + 1;
    final answer = queue != null && used < queue.length
        ? queue[used]
        : answers[itemKeys[item]];
    if (answer != null) {
      item.answerTex = answer.tex;
      item.formulas.addAll(answer.formulas);
      matched++;
    } else if (inline[item] case final d?) {
      item.answerTex = d.inlineAnswer;
      item.formulas.addAll(d.inlineFormulas);
    }
  }
  return ProblemExport(
    items,
    answers: answers.length + ansTo.values.fold<int>(0, (a, l) => a + l.length),
    unmatched:
        answers.length +
        ansTo.values.fold<int>(0, (a, l) => a + l.length) -
        matched,
    warnings: warnings,
  );
}

/// The export document: a generator/source/count header over the items.
Map<String, Object?> exportDocument(ProblemExport export, String file) => {
  'generator': 'manymath export_problem_bank',
  'source_file': file,
  'count': export.items.length,
  'items': [for (final item in export.items) item.toJson()],
};

String? _theoremKind(String noun) => switch (noun.toLowerCase()) {
  'theorem' || 'lemma' || 'corollary' => 'theorem',
  'proposition' => 'proposition',
  'example' => 'example',
  _ => null,
};

String _bookFromFile(String file) {
  final name = file.split(RegExp(r'[\\/]')).last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

String _slug(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');
