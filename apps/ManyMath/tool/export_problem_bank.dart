/// Exports the problem items in a LaTeX file as JSON for the math game.
///
///     dart run tool/export_problem_bank.dart book.tex [--book name] [--out bank.json] [--strict]
///
/// Prints to stdout unless `--out` is given; a summary goes to stderr. Repeated
/// ids or answer keys are reported as warnings, and fail the run with
/// `--strict`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:manymath/src/problem_export.dart';

void main(List<String> args) {
  String? file;
  String? book;
  String? out;
  var strict = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--book' when i + 1 < args.length:
        book = args[++i];
      case '--out' when i + 1 < args.length:
        out = args[++i];
      case '--strict':
        strict = true;
      case final arg when !arg.startsWith('--') && file == null:
        file = arg;
      default:
        stderr.writeln(
          'usage: export_problem_bank.dart <file.tex> [--book name] [--out file.json] [--strict]',
        );
        exit(64);
    }
  }
  if (file == null) {
    stderr.writeln(
      'usage: export_problem_bank.dart <file.tex> [--book name] [--out file.json] [--strict]',
    );
    exit(64);
  }

  final export = extractProblems(
    File(file).readAsStringSync(),
    file: file,
    book: book,
  );
  final json = const JsonEncoder.withIndent(
    '  ',
  ).convert(exportDocument(export, file));
  if (out == null) {
    stdout.writeln(json);
  } else {
    File(out).writeAsStringSync('$json\n');
  }

  final byKind = <String, int>{};
  for (final item in export.items) {
    byKind[item.kind] = (byKind[item.kind] ?? 0) + 1;
  }
  final withAnswer = export.items.where((i) => i.answerTex != null).length;
  stderr.writeln(
    '${export.items.length} items $byKind; $withAnswer with answers '
    '(${export.answers} answers read, ${export.unmatched} unmatched)',
  );
  for (final w in export.warnings) {
    stderr.writeln('warning: $w');
  }
  if (strict && export.warnings.isNotEmpty) exit(1);
}
