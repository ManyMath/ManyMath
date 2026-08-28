import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/preview_theme.dart';
import 'package:manymath/src/theme.dart';

void main() {
  test('app theme modes map to their document palettes', () {
    expect(previewThemeForAppMode(AppThemeMode.light), PreviewTheme.light);
    expect(previewThemeForAppMode(AppThemeMode.dark), PreviewTheme.dark);
    expect(previewThemeForAppMode(AppThemeMode.terminal), PreviewTheme.terminal);
    expect(previewThemeForAppMode(AppThemeMode.night), PreviewTheme.night);

    expect(previewThemeForAppMode(AppThemeMode.system), PreviewTheme.light);
    expect(
      previewThemeForAppMode(AppThemeMode.system, platformDark: true),
      PreviewTheme.dark,
    );
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
    expect(previewPalette(PreviewTheme.night).ink, const Color(0xFFFF8080));
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
