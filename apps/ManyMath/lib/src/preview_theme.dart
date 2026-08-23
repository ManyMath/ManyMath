import 'dart:ui' show Color;

/// Color scheme of the rendered document preview, independent of the
/// app-wide theme. The header toggle switches the whole app between light
/// and dark; the preview pane's own toggle cycles these four modes and
/// affects only the rendered paper.
enum PreviewTheme { light, dark, terminal, night }

extension PreviewThemeCycling on PreviewTheme {
  /// The next mode in the light -> dark -> terminal -> night cycle.
  PreviewTheme get next =>
      PreviewTheme.values[(index + 1) % PreviewTheme.values.length];

  String get label => switch (this) {
    PreviewTheme.light => 'Light',
    PreviewTheme.dark => 'Dark',
    PreviewTheme.terminal => 'Terminal',
    PreviewTheme.night => 'Night',
  };
}

/// A paper/ink pair plus the supporting shades the document view derives
/// from them (borders, code and theorem panels, dimmed text, TikZ label
/// halos), so every surface in a mode shares one hue family.
class PreviewPalette {
  const PreviewPalette._(this.paper, this.ink);

  final Color paper;
  final Color ink;

  Color get border => Color.alphaBlend(ink.withValues(alpha: 0.16), paper);
  Color get panel => Color.alphaBlend(ink.withValues(alpha: 0.05), paper);
  Color get frameBorder => Color.alphaBlend(ink.withValues(alpha: 0.45), paper);
  Color get dimText => Color.alphaBlend(ink.withValues(alpha: 0.72), paper);
  Color get labelHalo => paper.withValues(alpha: 0.9);
}

PreviewPalette previewPalette(PreviewTheme theme) => switch (theme) {
  PreviewTheme.light => const PreviewPalette._(
    Color(0xFFFFFFFF),
    Color(0xFF18201C),
  ),
  PreviewTheme.dark => const PreviewPalette._(
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ),
  PreviewTheme.terminal => const PreviewPalette._(
    Color(0xFF000000),
    Color(0xFF33FF33),
  ),
  PreviewTheme.night => const PreviewPalette._(
    Color(0xFF000000),
    Color(0xFFFF6666),
  ),
};
