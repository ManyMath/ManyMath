import 'dart:ui' show Color;

import 'theme.dart';

/// Color scheme of the rendered document preview. The preview has no toggle
/// of its own: it follows the app-wide [AppThemeMode], so the whole window
/// restyles together. [PreviewTheme.light] is also the export default —
/// documents rendered for export always use black ink on white paper,
/// regardless of the on-screen mode.
enum PreviewTheme { light, dark, terminal, night }

/// The document palette an app-wide theme mode maps to. System resolves by
/// the platform brightness the caller passes in.
PreviewTheme previewThemeForAppMode(
  AppThemeMode mode, {
  bool platformDark = false,
}) => switch (mode) {
  AppThemeMode.light => PreviewTheme.light,
  AppThemeMode.dark => PreviewTheme.dark,
  AppThemeMode.terminal => PreviewTheme.terminal,
  AppThemeMode.night => PreviewTheme.night,
  AppThemeMode.system => platformDark ? PreviewTheme.dark : PreviewTheme.light,
};

/// A paper/ink pair plus the supporting shades the document view derives
/// from them (borders, code and theorem panels, dimmed text, TikZ label
/// halos), so every surface in a mode shares one hue family.
class PreviewPalette {
  const PreviewPalette._(this.paper, this.ink, this.error);

  final Color paper;
  final Color ink;

  /// Formula error text, legible at caption size on [paper]: the app's red
  /// on white, a lighter red on black, and the ink itself in night mode,
  /// which keeps to one hue.
  final Color error;

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
    Color(0xFFB94350),
  ),
  PreviewTheme.dark => const PreviewPalette._(
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFFFF6B6B),
  ),
  PreviewTheme.terminal => const PreviewPalette._(
    Color(0xFF000000),
    Color(0xFF33FF33),
    Color(0xFFFF6B6B),
  ),
  PreviewTheme.night => const PreviewPalette._(
    Color(0xFF000000),
    Color(0xFFFF8080),
    Color(0xFFFF8080),
  ),
};
