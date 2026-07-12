import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';

const Color manyMathGreen = Color(0xFF2E7D32);
const Color manyMathGreenDark = Color(0xFF78C87C);

MThemeData manyMathLightTheme() {
  return MThemeData.workbenchLight(primary: manyMathGreen);
}

MThemeData manyMathDarkTheme() {
  return MThemeData.workbenchDark(
    primary: manyMathGreenDark,
    primaryForeground: const Color(0xFF0E1E12),
  );
}
