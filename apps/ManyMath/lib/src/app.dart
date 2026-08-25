import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';

import 'document_store.dart';
import 'editor_page.dart';
import 'formula_check.dart';
import 'latex_document.dart';
import 'theme.dart';

class ManyMathApp extends StatefulWidget {
  const ManyMathApp({
    required this.store,
    this.engineInitializer,
    this.formulaChecker,
    this.initialThemeMode,
    this.persistentStorage = true,
    super.key,
  });

  final DocumentStore store;
  final Future<void> Function()? engineInitializer;
  final List<FormulaIssue> Function(List<DocBlock>)? formulaChecker;
  final AppThemeMode? initialThemeMode;
  final bool persistentStorage;

  @override
  State<ManyMathApp> createState() => _ManyMathAppState();
}

class _ManyMathAppState extends State<ManyMathApp> with WidgetsBindingObserver {
  late AppThemeMode _themeMode =
      widget.initialThemeMode ?? widget.store.appThemeMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.store.save();
      unawaited(widget.store.flush().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _cycleTheme() {
    final next = _themeMode.next;
    widget.store.appThemeMode = next;
    setState(() {
      _themeMode = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MWidgetsApp(
      title: 'ManyMath Editor',
      color: manyMathGreen,
      theme: _themeMode == AppThemeMode.night
          ? manyMathNightTheme()
          : manyMathLightTheme(),
      darkTheme: manyMathDarkTheme(),
      // manyui's MThemeMode has no night value, so night mode rides the
      // light slot, which holds the night theme above.
      themeMode: switch (_themeMode) {
        AppThemeMode.system => MThemeMode.system,
        AppThemeMode.dark => MThemeMode.dark,
        AppThemeMode.light || AppThemeMode.night => MThemeMode.light,
      },
      debugShowCheckedModeBanner: false,
      home: EditorPage(
        store: widget.store,
        engineInitializer: widget.engineInitializer,
        formulaChecker: widget.formulaChecker,
        persistentStorage: widget.persistentStorage,
        themeMode: _themeMode,
        onCycleTheme: _cycleTheme,
      ),
    );
  }
}
