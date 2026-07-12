import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manymath/src/templates.dart';

void main() {
  test(
    'starter templates have unique names and renderable document bodies',
    () {
      expect(
        documentTemplates.map((template) => template.name).toSet(),
        hasLength(documentTemplates.length),
      );
      for (final template in documentTemplates) {
        expect(
          template.source,
          contains(r'\begin{document}'),
          reason: template.name,
        );
        expect(
          template.source,
          contains(r'\end{document}'),
          reason: template.name,
        );
        expect(
          parseLatexDocument(template.source),
          isNotEmpty,
          reason: template.name,
        );
      }
    },
  );

  test('welcome template remains the article sample', () {
    expect(welcomeTemplate, same(articleTemplate));
    expect(welcomeTemplate.source, contains('Basel Problem'));
  });
}
