import 'package:flutter/foundation.dart';
import 'package:ratex_flutter/ratex_flutter.dart';

import 'latex_document.dart';

class FormulaIssue {
  const FormulaIssue({
    required this.latex,
    required this.message,
    required this.displayMode,
    this.sourceStart,
    this.sourceEnd,
    this.errorStart,
    this.errorEnd,
  });

  final String latex;
  final String message;
  final bool displayMode;
  final int? sourceStart;
  final int? sourceEnd;
  final int? errorStart;
  final int? errorEnd;

  (int, int)? get selection {
    if (errorStart != null && errorEnd != null) {
      return (errorStart!, errorEnd!);
    }
    if (sourceStart != null && sourceEnd != null) {
      return (sourceStart!, sourceEnd!);
    }
    return null;
  }
}

List<FormulaIssue> checkFormulas(
  List<DocBlock> blocks, {
  String macroPreamble = '',
}) {
  final issues = <FormulaIssue>[];
  final preambleUnits = macroPreamble.length;

  void check(
    String latex, {
    required bool displayMode,
    int? start,
    int? end,
    List<int>? latexSourceMap,
  }) {
    final combined = macroPreamble + latex;
    RatexException failure;
    try {
      Ratex.renderDisplayListSync(
        combined,
        options: RatexOptions(displayMode: displayMode),
      );
      return;
    } on RatexException catch (error) {
      failure = error;
    } on Object catch (error) {
      failure = RatexInternalException('$error');
    }

    int? errorStart;
    int? errorEnd;
    if (failure is RatexParseException &&
        failure.hasSpan &&
        latexSourceMap != null &&
        latexSourceMap.isNotEmpty) {
      final unitStart = codeUnitForByte(combined, failure.start!) - preambleUnits;
      final unitEnd = codeUnitForByte(combined, failure.end!) - preambleUnits;
      // A negative offset means the failure is inside the synthesized macro
      // preamble itself, not the formula the user can see and edit; leave
      // the jump target null so the issue falls back to the block/span
      // source span instead of pointing at text that isn't in the editor.
      if (unitStart >= 0) {
        errorStart = unitStart < latexSourceMap.length
            ? latexSourceMap[unitStart]
            : latexSourceMap.last + 1;
        errorEnd = unitEnd > unitStart && unitEnd <= latexSourceMap.length
            ? latexSourceMap[unitEnd - 1] + 1
            : errorStart + 1;
        if (errorEnd <= errorStart) errorEnd = errorStart + 1;
      }
    }
    issues.add(
      FormulaIssue(
        latex: latex,
        message: failure.message,
        displayMode: displayMode,
        sourceStart: start,
        sourceEnd: end,
        errorStart: errorStart,
        errorEnd: errorEnd,
      ),
    );
  }

  void checkInlines(List<DocInline> spans) {
    for (final span in spans) {
      if (span is InlineMath) {
        check(
          span.latex,
          displayMode: false,
          start: span.sourceStart,
          end: span.sourceEnd,
          latexSourceMap: span.latexSourceMap,
        );
      }
    }
  }

  void checkBlocks(List<DocBlock> blocks) {
    for (final block in blocks) {
      switch (block) {
        case DisplayMathBlock():
          check(
            block.latex,
            displayMode: true,
            start: block.sourceStart,
            end: block.sourceEnd,
            latexSourceMap: block.latexSourceMap,
          );
        case ParagraphBlock():
          checkInlines(block.spans);
        case HeadingBlock():
          checkInlines(block.spans);
        case ListBlock():
          block.items.forEach(checkBlocks);
        case TitleBlock():
          for (final metadata in <({String? value, List<int>? sourceMap})>[
            (value: block.title, sourceMap: block.titleSourceMap),
            (value: block.author, sourceMap: block.authorSourceMap),
            (value: block.date, sourceMap: block.dateSourceMap),
          ]) {
            if (metadata.value != null) {
              checkInlines(
                parseInline(metadata.value!, sourceMap: metadata.sourceMap),
              );
            }
          }
        case BibliographyBlock():
          for (final entry in block.entries) {
            checkInlines(entry.spans);
          }
        case QuoteBlock():
          checkBlocks(block.children);
        case TheoremBlock():
          if (block.title != null) checkInlines(block.title!);
          checkBlocks(block.body);
        case CodeBlock():
        // Verbatim text: nothing to check, RaTeX never sees it.
      }
    }
  }

  checkBlocks(blocks);
  return issues;
}

@visibleForTesting
int codeUnitForByte(String source, int targetByte) {
  var byte = 0;
  var unit = 0;
  for (final rune in source.runes) {
    if (byte >= targetByte) return unit;
    byte += rune < 0x80
        ? 1
        : rune < 0x800
        ? 2
        : rune < 0x10000
        ? 3
        : 4;
    unit += rune > 0xffff ? 2 : 1;
  }
  return unit;
}
