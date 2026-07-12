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
  final MThemeMode? initialThemeMode;
  final bool persistentStorage;

  @override
  State<ManyMathApp> createState() => _ManyMathAppState();
}

class _ManyMathAppState extends State<ManyMathApp> with WidgetsBindingObserver {
  late MThemeMode _themeMode =
      widget.initialThemeMode ?? widget.store.themeMode;

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

  void _toggleTheme(bool currentlyDark) {
    final next = currentlyDark ? MThemeMode.light : MThemeMode.dark;
    widget.store.themeMode = next;
    setState(() {
      _themeMode = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MWidgetsApp(
      title: 'ManyMath Editor',
      color: manyMathGreen,
      theme: manyMathLightTheme(),
      darkTheme: manyMathDarkTheme(),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: EditorPage(
        store: widget.store,
        engineInitializer: widget.engineInitializer,
        formulaChecker: widget.formulaChecker,
        persistentStorage: widget.persistentStorage,
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
