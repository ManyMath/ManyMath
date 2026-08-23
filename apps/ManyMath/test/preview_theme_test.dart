import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/preview_theme.dart';

void main() {
  test('preview theme cycles light -> dark -> terminal -> night -> light', () {
    var theme = PreviewTheme.light;
    final seen = <PreviewTheme>[theme];
    for (var i = 0; i < 4; i++) {
      theme = theme.next;
      seen.add(theme);
    }
    expect(seen, <PreviewTheme>[
      PreviewTheme.light,
      PreviewTheme.dark,
      PreviewTheme.terminal,
      PreviewTheme.night,
      PreviewTheme.light,
    ]);
  });

  test('palettes: light keeps the legacy pair, others are ink on black', () {
    final light = previewPalette(PreviewTheme.light);
    expect(light.paper, const Color(0xFFFFFFFF));
    expect(light.ink, const Color(0xFF18201C));

    final dark = previewPalette(PreviewTheme.dark);
    expect(dark.paper, const Color(0xFF000000));
    expect(dark.ink, const Color(0xFFFFFFFF));

    expect(
      previewPalette(PreviewTheme.terminal).paper,
      const Color(0xFF000000),
    );
    expect(previewPalette(PreviewTheme.terminal).ink, const Color(0xFF33FF33));
    expect(previewPalette(PreviewTheme.night).paper, const Color(0xFF000000));
    expect(previewPalette(PreviewTheme.night).ink, const Color(0xFFFF6666));
  });

  test('derived shades stay between paper and ink', () {
    for (final theme in PreviewTheme.values) {
      final palette = previewPalette(theme);
      for (final shade in <Color>[
        palette.border,
        palette.panel,
        palette.frameBorder,
        palette.dimText,
      ]) {
        expect(shade.a, 1.0);
      }
      expect(palette.labelHalo.a, closeTo(0.9, 0.01));
    }
  });
}
