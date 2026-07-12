import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/editor_toolbar.dart';
import 'package:manymath/src/formula_check.dart';

void main() {
  group('applySnippet', () {
    test('wraps a selection and parks the cursor after it', () {
      const value = TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
      );

      final result = applySnippet(value, snippetBold);

      expect(result.text, r'\textbf{hello} world');
      expect(result.selection.isCollapsed, isTrue);
      expect(result.selection.baseOffset, r'\textbf{hello}'.length);
    });

    test('inserts and selects a placeholder at the cursor', () {
      const value = TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = applySnippet(value, snippetInlineMath);

      expect(result.text, r'a$x$b');
      expect(
        result.selection,
        const TextSelection(baseOffset: 2, extentOffset: 3),
      );
    });

    test('appends when the controller has no valid selection', () {
      const value = TextEditingValue(text: 'xy');

      final result = applySnippet(value, snippetItalic);

      expect(result.text, r'xy\textit{italic text}');
      expect(result.selection.baseOffset, r'xy\textit{'.length);
      expect(
        result.selection.extentOffset,
        r'xy\textit{'.length + 'italic text'.length,
      );
    });

    test('matrix and align snippets contain only valid template text', () {
      final matrix = applySnippet(
        const TextEditingValue(text: ''),
        insertSnippets.firstWhere((snippet) => snippet.label == 'Matrix'),
      );
      final align = applySnippet(
        const TextEditingValue(text: ''),
        insertSnippets.firstWhere(
          (snippet) => snippet.label == 'Align environment',
        ),
      );

      expect(matrix.text, contains('    c & d'));
      expect(matrix.text, isNot(contains('\n+')));
      expect(align.text, contains('  c &= d'));
      expect(align.text, isNot(contains('\n+')));
    });
  });

  group('codeUnitForByte', () {
    test('maps UTF-8 byte offsets to UTF-16 code units', () {
      expect(codeUnitForByte('abc', 2), 2);
      expect(codeUnitForByte('π2', 2), 1);
      expect(codeUnitForByte('😀x', 4), 2);
    });

    test('clamps offsets beyond the string', () {
      expect(codeUnitForByte('abc', 10), 3);
    });
  });
}
