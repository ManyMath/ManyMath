import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';

const Color manyMathGreen = Color(0xFF2E7D32);
const Color manyMathGreenDark = Color(0xFF78C87C);

/// The phosphor green shared by the app-wide terminal mode and its toggle
/// icon, matching the preview pane's terminal ink.
const Color manyMathTerminalGreen = Color(0xFF33FF33);

/// The red shared by the app-wide night mode and its toggle icon, matching
/// the preview pane's night mode ink.
const Color manyMathNightRed = Color(0xFFFF3333);

/// The app-wide color schemes; the document preview follows the same mode,
/// so one header toggle restyles the whole window at once. System only
/// exists as a starting point; the toggle scrolls the explicit
/// light -> dark -> terminal -> night -> light cycle.
enum AppThemeMode { system, light, dark, terminal, night }

extension AppThemeModeCycling on AppThemeMode {
  AppThemeMode get next => switch (this) {
    AppThemeMode.light => AppThemeMode.dark,
    AppThemeMode.dark => AppThemeMode.terminal,
    AppThemeMode.terminal => AppThemeMode.night,
    AppThemeMode.night || AppThemeMode.system => AppThemeMode.light,
  };

  String get label => switch (this) {
    AppThemeMode.system => 'System',
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
    AppThemeMode.terminal => 'Terminal',
    AppThemeMode.night => 'Night',
  };
}

MThemeData manyMathLightTheme() {
  return MThemeData.workbenchLight(primary: manyMathGreen);
}

MThemeData manyMathDarkTheme() {
  return MThemeData.workbenchDark(
    primary: manyMathGreenDark,
    primaryForeground: const Color(0xFF0E1E12),
  );
}

/// Green-on-black terminal theme: the same layering as night mode with
/// every text and accent token pulled toward [manyMathTerminalGreen].
MThemeData manyMathTerminalTheme() {
  const Color green = manyMathTerminalGreen;
  return MThemeData(
    colors: MColorScheme(
      background: const Color(0xFF000000),
      foreground: green,
      card: const Color(0xFF0A0A0A),
      cardForeground: green,
      popover: const Color(0xFF0A0A0A),
      popoverForeground: green,
      primary: green,
      primaryForeground: const Color(0xFF000000),
      secondary: const Color(0xFF0F1F0F),
      secondaryForeground: const Color(0xFF66FF66),
      muted: const Color(0xFF0A140A),
      mutedForeground: const Color(0xFF55B355),
      accent: Color.alphaBlend(
        green.withValues(alpha: 0.16),
        const Color(0xFF0A140A),
      ),
      accentForeground: green,
      destructive: const Color(0xFFB94350),
      destructiveForeground: const Color(0xFFFFFFFF),
      border: const Color(0xFF143314),
      input: const Color(0xFF184018),
      ring: green,
    ),
    typography: const MTypography.workbench(),
    radius: 7,
  );
}

/// Red-on-black night theme: the workbench dark layering with every text
/// and accent token pulled toward [manyMathNightRed].
MThemeData manyMathNightTheme() {
  const Color red = manyMathNightRed;
  return MThemeData(
    colors: MColorScheme(
      background: const Color(0xFF000000),
      foreground: red,
      card: const Color(0xFF0A0A0A),
      cardForeground: red,
      popover: const Color(0xFF0A0A0A),
      popoverForeground: red,
      primary: red,
      primaryForeground: const Color(0xFF000000),
      secondary: const Color(0xFF1F0F0F),
      secondaryForeground: const Color(0xFFFF6666),
      muted: const Color(0xFF140A0A),
      mutedForeground: const Color(0xFFB35555),
      accent: Color.alphaBlend(
        red.withValues(alpha: 0.16),
        const Color(0xFF140A0A),
      ),
      accentForeground: red,
      destructive: const Color(0xFFB94350),
      destructiveForeground: const Color(0xFFFFFFFF),
      border: const Color(0xFF331414),
      input: const Color(0xFF401818),
      ring: red,
    ),
    typography: const MTypography.workbench(),
    radius: 7,
  );
}
