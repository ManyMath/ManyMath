import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/compat_macros.g.dart';
import 'package:manymath/src/latex_document.dart';

import 'support/integration_fixtures.dart';

// Exact renderer contract snapshots are versioned in tool/integration-lock.json.
String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  final fixtures =
      (jsonDecode(
                integrationFixture(
                  'ratex/compat_fixtures.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['fixtures']
          as List;

  test('the generated table matches compat_macros.json', () {
    final macros =
        (jsonDecode(
                  integrationFixture(
                    'ratex/compat_macros.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['macros']
            as List;
    expect(compatMacros.keys, [for (final m in macros) m['name']]);
    for (final m in macros) {
      final generated = compatMacros[m['name']]!;
      expect(generated.arity, m['arity'], reason: '${m['name']}');
      expect(generated.category, m['category'], reason: '${m['name']}');
      expect(generated.optional, m['optional'] ?? false);
    }
  });

  group('shared fixtures', () {
    for (final fixture in fixtures.cast<Map<String, dynamic>>()) {
      test('${fixture['id']} (${fixture['mode']})', () {
        final input = fixture['input'] as String;
        final normalized = fixture['mode'] == 'prose'
            ? normalizeCompatProse(input)
            : normalizeCompatMath(input);
        expect(_collapse(normalized), fixture['normalized']);
      });
    }
  });

  test('prose normalization leaves math macros for the formulas', () {
    expect(normalizeCompatProse(r'\ds \efrac{1}{2}'), r'\ds \efrac{1}{2}');
  });

  group('optional arguments with braces', () {
    test(r'a ] inside braces does not end \First[...]', () {
      final out = normalizeCompatProse(r'\First[{a]b}]{Xyz} rest');
      expect(out, isNot(contains(r'\First')));
      expect(out, isNot(contains('[')));
      expect(out, contains('Xyz'));
      expect(out, contains('rest'));
    });

    test('a plain optional argument still goes', () {
      final out = normalizeCompatProse(r'\First[x]{Xyz} rest');
      expect(out, isNot(contains(r'\First')));
      expect(out, contains('Xyz'));
    });

    test('keeps later source offsets aligned', () {
      const src = r'\First[{a]b}]{Xyz} then $x+1$.';
      final p = parseLatexDocument(src).whereType<ParagraphBlock>().single;
      expect(
        p.spans.whereType<TextRun>().map((t) => t.text).join(),
        contains('Xyz then'),
      );
      final math = p.spans.whereType<InlineMath>().single;
      expect(src.substring(math.sourceStart!).startsWith(r'$x+1'), isTrue);
    });
  });
}
