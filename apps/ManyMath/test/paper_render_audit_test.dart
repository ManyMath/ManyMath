/// Renders all 8 bundled papers through the document parser and audits the
/// result: no raw LaTeX may leak into prose runs, and every formula handed
/// to RaTeX must compile (except the known-undefined citation keys).
///
/// Run with `--dart-define=AUDIT_VERBOSE=true` to print every leak with
/// context instead of just failing.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/formula_check.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manymath/src/papers.dart';
import 'package:ratex_flutter/ratex_flutter.dart';

const _verbose = bool.fromEnvironment('AUDIT_VERBOSE');

/// Backslash commands and environment markers: none of these belong in a
/// plain prose run after parsing. Bare `&`/`~`/`^` are NOT flagged — after
/// parsing they are legitimate rendered output (`\&`, `\textasciitilde`,
/// verbatim `\url` arguments), while raw alignment/nbsp uses always travel
/// with backslash commands that are flagged.
final _leakRe = RegExp(r'\\[a-zA-Z]+|\\begin\{|\\end\{');

void _collectLeaks(List<DocInline> spans, List<String> leaks, String where) {
  for (final span in spans) {
    if (span is! TextRun) continue;
    for (final m in _leakRe.allMatches(span.text)) {
      final start = m.start < 30 ? 0 : m.start - 30;
      final end = m.end + 40 > span.text.length ? span.text.length : m.end + 40;
      leaks.add('[$where] …${span.text.substring(start, end)}…');
    }
  }
}

void _walkBlocks(List<DocBlock> blocks, List<String> leaks, String where) {
  for (final block in blocks) {
    switch (block) {
      case ParagraphBlock():
        _collectLeaks(block.spans, leaks, '$where/p');
      case HeadingBlock():
        _collectLeaks(block.spans, leaks, '$where/h${block.level}');
      case ListBlock():
        for (final item in block.items) {
          _walkBlocks(item, leaks, '$where/li');
        }
      case QuoteBlock():
        _walkBlocks(block.children, leaks, '$where/quote');
      case TheoremBlock():
        if (block.title != null) {
          _collectLeaks(block.title!, leaks, '$where/thm-title');
        }
        _walkBlocks(block.body, leaks, '$where/thm');
      case BibliographyBlock():
        for (final entry in block.entries) {
          _collectLeaks(entry.spans, leaks, '$where/bib');
        }
      case TableBlock():
        for (final row in block.rows) {
          for (final cell in row) {
            _collectLeaks(cell.spans, leaks, '$where/td');
          }
        }
      case CenterBlock():
        _walkBlocks(block.children, leaks, '$where/center');
      case FramedBlock():
        _walkBlocks(block.children, leaks, '$where/frame');
      case CaptionBlock():
        _collectLeaks(block.spans, leaks, '$where/caption');
      case FootnoteBlock():
        _collectLeaks(block.spans, leaks, '$where/fn');
      case TitleBlock():
        for (final metadata in [block.title, block.author, block.date]) {
          if (metadata != null) {
            _collectLeaks(parseInline(metadata), leaks, '$where/title');
          }
        }
      case DisplayMathBlock():
      case CodeBlock():
      case DiagramBlock():
        break;
    }
  }
}

void main() {
  final libraryName = Platform.isMacOS
      ? 'libratex_ffi.dylib'
      : Platform.isWindows
      ? 'ratex_ffi.dll'
      : 'libratex_ffi.so';
  final library = <String>[
    '../ratex/native/ratex-ffi/target/debug/$libraryName',
    '../ratex/native/ratex-ffi/target/release/$libraryName',
    '../../../ratex/native/ratex-ffi/target/debug/$libraryName',
    '../../../ratex/native/ratex-ffi/target/release/$libraryName',
  ].map(File.new).where((file) => file.existsSync()).firstOrNull;
  final skip = library == null ? 'native ratex_ffi not built' : false;

  setUpAll(() async {
    if (library == null) return;
    Ratex.nativeLibraryPath = library.absolute.path;
    await Ratex.ensureInitialized();
  });

  for (final paper in papers) {
    test('${paper.name}: no raw LaTeX leaks, all formulas compile', () {
      final blocks = parseLatexDocument(paper.source);
      final preamble = extractMacroPreamble(paper.source);

      final leaks = <String>[];
      _walkBlocks(blocks, leaks, paper.name);

      final issues = checkFormulas(blocks, macroPreamble: preamble);

      if (_verbose) {
        // ignore: avoid_print
        print(
          '=== ${paper.name}: ${leaks.length} leaks, '
          '${issues.length} formula issues',
        );
        for (final leak in leaks) {
          // ignore: avoid_print
          print('LEAK  $leak');
        }
        for (final issue in issues) {
          // ignore: avoid_print
          print('MATH  ${issue.message}\n      ${issue.latex}');
        }
      }

      expect(leaks, isEmpty, reason: 'raw LaTeX leaked into prose');
      expect(
        issues.map((issue) => '${issue.message} in: ${issue.latex}').toList(),
        isEmpty,
        reason: 'formulas failed to compile',
      );
    }, skip: skip);
  }
}
