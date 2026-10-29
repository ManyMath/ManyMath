import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/app.dart';
import 'package:manymath/src/document_browser.dart';
import 'package:manymath/src/document_store.dart';
import 'package:manymath/src/document_view.dart';
import 'package:manymath/src/editor_page.dart';
import 'package:manymath/src/formula_check.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manymath/src/page_setup.dart';
import 'package:manymath/src/papers.dart';
import 'package:manymath/src/preview_theme.dart';
import 'package:manymath/src/theme.dart';
import 'package:manyui/manyui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quota_preferences.dart';

void main() {
  Future<void> settleRender(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pumpAndSettle();
  }

  Future<DocumentStore> pumpEditor(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    Future<void> Function()? engineInitializer,
    String initialSource = 'Initial document',
    DocumentStore? store,
    List<FormulaIssue> Function(List<DocBlock>)? formulaChecker,
    bool persistentStorage = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final documentStore =
        store ??
        DocumentStore.inMemory(
          documents: <ManyMathDocument>[
            ManyMathDocument(
              id: 'test-document',
              name: 'Test document',
              source: initialSource,
              updatedAt: DateTime.utc(2026),
            ),
          ],
        );
    await tester.pumpWidget(
      ManyMathApp(
        store: documentStore,
        engineInitializer: engineInitializer ?? () async {},
        formulaChecker: formulaChecker ?? (_) => const <FormulaIssue>[],
        initialThemeMode: AppThemeMode.light,
        persistentStorage: persistentStorage,
      ),
    );
    await tester.pump();
    await tester.pump();
    await settleRender(tester);
    return documentStore;
  }

  testWidgets('file menu button shows a document glyph with an ellipsis', (
    tester,
  ) async {
    await pumpEditor(tester);

    final button = find.byWidgetPredicate(
      (widget) => widget is MButton && widget.semanticLabel == 'More actions',
    );
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.byType(MIcon)),
      findsNWidgets(2),
    );

    await tester.tap(button);
    await tester.pump();
    expect(find.text('New document'), findsOneWidget);
  });

  testWidgets('desktop workspace presents resizable source and preview panes', (
    tester,
  ) async {
    await pumpEditor(tester);

    expect(find.byType(MResizable), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is MSegmentedControl<EditorSurface>,
      ),
      findsNothing,
    );
    expect(find.byType(EditableText), findsOneWidget);
    expect(find.text('Rendered'), findsOneWidget);
    expect(find.bySemanticsLabel('Preview status: Rendered'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Saved locally'), findsOneWidget);
    expect(find.bySemanticsLabel('LaTeX source editor'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Source and preview pane sizes'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop panes independently minimize, expand, and fullscreen', (
    tester,
  ) async {
    await pumpEditor(tester);

    expect(find.bySemanticsLabel('Minimize documents'), findsOneWidget);
    expect(find.bySemanticsLabel('Minimize source'), findsOneWidget);
    expect(find.bySemanticsLabel('Minimize preview'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Minimize documents'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('expand-Documents-pane')),
      findsOneWidget,
    );
    expect(find.byType(EditableText), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('expand-Documents-pane')),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Minimize documents'), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Minimize source'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('expand-Source-pane')),
      findsOneWidget,
    );
    expect(find.byType(MResizable), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('expand-Source-pane')));
    await tester.pump();

    expect(find.byType(MResizable), findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel('Minimize preview'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('expand-Preview-pane')),
      findsOneWidget,
    );
    expect(find.byType(EditableText), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('expand-Preview-pane')));
    await tester.pump();

    expect(find.byType(MResizable), findsNWidgets(2));

    expect(find.bySemanticsLabel('Maximize preview'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Maximize preview'));
    await tester.pump();

    expect(find.byType(MResizable), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('expand-Documents-pane')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('expand-Source-pane')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Restore split view'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('expand-Source-pane')));
    await tester.pump();

    expect(find.byType(MResizable), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('expand-Documents-pane')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Maximize preview'), findsOneWidget);
  });

  testWidgets('documents pane separator drags to resize', (tester) async {
    await pumpEditor(tester);

    final browser = find.byType(DocumentBrowser);
    expect(browser, findsOneWidget);
    final before = tester.getSize(browser).width;

    final resizable = find.bySemanticsLabel('Documents and editor pane sizes');
    expect(resizable, findsOneWidget);
    final rect = tester.getRect(resizable);
    await tester.dragFrom(
      Offset(rect.left + before, rect.center.dy),
      const Offset(80, 0),
    );
    await tester.pump();

    expect(tester.getSize(browser).width, greaterThan(before));
  });

  testWidgets('source maximize minimizes the other panes', (tester) async {
    await pumpEditor(tester);

    expect(find.bySemanticsLabel('Maximize source'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Maximize source'));
    await tester.pump();

    expect(find.byType(MResizable), findsNothing);
    expect(find.byType(EditableText), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('expand-Preview-pane')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('expand-Documents-pane')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Restore split view'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Restore split view'));
    await tester.pump();

    expect(find.byType(MResizable), findsNWidgets(2));
    expect(find.bySemanticsLabel('Maximize source'), findsOneWidget);
  });

  testWidgets('compact workspace switches between source and preview', (
    tester,
  ) async {
    await pumpEditor(tester, size: const Size(390, 844));

    final segmentedControl = find.byWidgetPredicate(
      (widget) => widget is MSegmentedControl<EditorSurface>,
    );
    expect(segmentedControl, findsOneWidget);
    expect(find.byType(MResizable), findsNothing);
    expect(find.text('Documents'), findsNothing);
    expect(find.bySemanticsLabel('Open documents'), findsOneWidget);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);

    await tester.tap(
      find.descendant(of: segmentedControl, matching: find.text('Preview')),
    );
    await tester.pump();

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
    expect(find.bySemanticsLabel('Rendered document preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone landscape keeps the editor usable without overflow', (
    tester,
  ) async {
    await pumpEditor(tester, size: const Size(844, 390));

    expect(find.byType(MResizable), findsOneWidget);
    expect(tester.getSize(find.byType(EditableText)).height, greaterThan(60));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable local storage is clearly disclosed', (tester) async {
    await pumpEditor(tester, persistentStorage: false);

    expect(find.text('Temporary session'), findsOneWidget);
    expect(find.textContaining('Local storage is unavailable'), findsOneWidget);
    expect(find.text('Saved locally'), findsNothing);
  });

  testWidgets('a save that failed while loading is reported', (tester) async {
    final store = await DocumentStore.load(
      preferences: QuotaPreferences(<String, Object>{}),
    );
    await pumpEditor(tester, store: store);

    expect(find.text('Could not save the local document.'), findsOneWidget);
    expect(store.documents, hasLength(papers.length));
  });

  testWidgets('recovered data can be copied and dismissed', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DocumentStore.documentsStorageKey: 'not json {',
    });
    final store = await DocumentStore.load(now: () => DateTime.utc(2026));
    expect(store.recoveryPayload, 'not json {');
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpEditor(tester, store: store);

    expect(find.text('Local data recovered'), findsOneWidget);
    await tester.tap(find.text('Copy data'));
    await tester.pump();
    expect(copied, 'not json {');

    await tester.tap(find.text('Dismiss'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pumpAndSettle();
    expect(store.recoveryPayload, isNull);
    expect(find.text('Local data recovered'), findsNothing);
  });

  testWidgets('compact document button opens the local document browser', (
    tester,
  ) async {
    await pumpEditor(tester, size: const Size(390, 844));

    await tester.tap(find.bySemanticsLabel('Open documents'));
    await tester.pumpAndSettle();

    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Test document'), findsWidgets);
    expect(find.bySemanticsLabel('Close documents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact document actions close the browser sheet first', (
    tester,
  ) async {
    await pumpEditor(tester, size: const Size(390, 844));

    await tester.tap(find.bySemanticsLabel('Open documents'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('New document'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Close documents'), findsNothing);
    expect(find.text('New document'), findsOneWidget);
    expect(find.text('Template'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app and document headings expose a useful hierarchy', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      initialSource: r'''
\title{Structured document}
\begin{document}
\maketitle
\section{First section}
Content.
\end{document}
''',
    );

    final preview = find.byType(DocumentView);
    final documentTitle = find.descendant(
      of: preview,
      matching: find.text('Structured document'),
    );
    final sectionTitle = find.descendant(
      of: preview,
      matching: find.text('First section'),
    );

    expect(tester.getSemantics(find.text('ManyMath')).headingLevel, 1);
    expect(tester.getSemantics(documentTitle).headingLevel, 2);
    expect(tester.getSemantics(sectionTitle).headingLevel, 3);
  });

  testWidgets('preview lazily builds only visible document blocks', (
    tester,
  ) async {
    final source = List<String>.generate(
      300,
      (index) => 'Paragraph $index',
    ).join('\n\n');
    await pumpEditor(tester, initialSource: source);

    // Native compute can finish after pumpAndSettle finds no scheduled frames.
    // Wait for the mounted parsed model, rather than the early Rendered label.
    final parsing = Stopwatch()..start();
    while (true) {
      final previews = tester.widgetList<DocumentView>(
        find.byType(DocumentView),
      );
      if (previews.length == 1 && previews.single.blocks.length == 300) break;
      if (parsing.elapsed >= const Duration(seconds: 10)) {
        fail(
          'Timed out waiting for the mounted preview to contain 300 blocks.',
        );
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Paragraph 0'), findsOneWidget);
    expect(find.text('Paragraph 299'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(DocumentView),
        matching: find.byType(CustomScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets('editing marks the preview pending until an explicit render', (
    tester,
  ) async {
    await pumpEditor(tester, initialSource: 'Original document');

    expect(find.text('Original document'), findsNWidgets(2));
    await tester.enterText(
      find.bySemanticsLabel('LaTeX source editor'),
      'Updated document',
    );
    await tester.pump();

    expect(find.text('Changes pending'), findsOneWidget);
    expect(find.text('Original document'), findsOneWidget);
    expect(find.text('Updated document'), findsOneWidget);

    await tester.enterText(
      find.bySemanticsLabel('LaTeX source editor'),
      'Second edit is longer',
    );
    await tester.pump();

    expect(find.textContaining('21 characters'), findsOneWidget);
    expect(find.text('Original document'), findsOneWidget);

    await tester.tap(find.text('Auto render'));
    await settleRender(tester);

    expect(find.text('Rendered'), findsOneWidget);
    expect(find.text('Second edit is longer'), findsNWidgets(2));
    expect(find.text('Original document'), findsNothing);
  });

  testWidgets('the character count counts an astral character once', (
    tester,
  ) async {
    await pumpEditor(tester, initialSource: 'abc \u{1D44E}');
    expect(find.textContaining('5 characters'), findsOneWidget);
  });

  testWidgets('the auto render button toggles automatic rendering on and off', (
    tester,
  ) async {
    var formulaChecks = 0;
    await pumpEditor(
      tester,
      initialSource: 'Original document',
      formulaChecker: (_) {
        formulaChecks += 1;
        return const <FormulaIssue>[];
      },
    );
    expect(formulaChecks, 1);

    final toggle = find.byWidgetPredicate(
      (widget) =>
          widget is MButton &&
          (widget.semanticLabel ?? '').startsWith('Auto render:'),
    );
    expect(tester.widget<MButton>(toggle).semanticLabel, contains('off'));

    await tester.tap(find.text('Auto render'));
    await tester.pump();
    expect(tester.widget<MButton>(toggle).semanticLabel, contains('on'));

    await tester.enterText(
      find.bySemanticsLabel('LaTeX source editor'),
      'First automatic draft',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Changes pending'), findsOneWidget);
    expect(find.text('Original document'), findsOneWidget);

    await tester.enterText(
      find.bySemanticsLabel('LaTeX source editor'),
      'Rendered automatically',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Changes pending'), findsOneWidget);
    expect(find.text('Original document'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 50));
    await settleRender(tester);

    expect(find.text('Changes pending'), findsNothing);
    expect(find.text('Rendered automatically'), findsNWidgets(2));
    expect(formulaChecks, 1);

    await tester.tap(find.text('Auto render'));
    await tester.pump();
    expect(tester.widget<MButton>(toggle).semanticLabel, contains('off'));

    await tester.enterText(
      find.bySemanticsLabel('LaTeX source editor'),
      'Never rendered draft',
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Changes pending'), findsOneWidget);
  });

  testWidgets('renderer failure offers a working retry', (tester) async {
    var attempts = 0;
    Future<void> initialize() async {
      attempts += 1;
      if (attempts == 1) throw StateError('renderer did not start');
    }

    await pumpEditor(tester, engineInitializer: initialize);

    expect(attempts, 1);
    expect(find.text('Renderer unavailable'), findsNWidgets(2));
    expect(find.textContaining('renderer did not start'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await settleRender(tester);

    expect(attempts, 2);
    expect(find.text('Rendered'), findsOneWidget);
    expect(find.text('Renderer unavailable'), findsNothing);
  });

  testWidgets('Control Enter renders while the source editor is focused', (
    tester,
  ) async {
    await pumpEditor(tester, initialSource: 'Original document');

    await tester.enterText(
      find.bySemanticsLabel('LaTeX source editor'),
      'Keyboard render',
    );
    await tester.pump();
    expect(find.text('Changes pending'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settleRender(tester);

    expect(find.text('Rendered'), findsOneWidget);
    expect(find.text('Keyboard render'), findsNWidgets(2));
  });

  testWidgets('theme action is labeled by the result it produces', (
    tester,
  ) async {
    await pumpEditor(tester);

    expect(find.bySemanticsLabel('Use dark theme'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Use dark theme'));
    await tester.pump();

    expect(find.bySemanticsLabel('Use terminal theme'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Use terminal theme'));
    await tester.pump();

    expect(find.bySemanticsLabel('Use night theme'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Use night theme'));
    await tester.pump();

    expect(find.bySemanticsLabel('Use light theme'), findsOneWidget);
  });

  testWidgets('an edit reaches the document store without a debounce window', (
    tester,
  ) async {
    final store = DocumentStore.inMemory(
      documents: <ManyMathDocument>[
        ManyMathDocument(
          id: 'persisted',
          name: 'Persisted',
          source: 'Before',
          updatedAt: DateTime.utc(2026),
        ),
      ],
    );
    await pumpEditor(tester, store: store);

    await tester.enterText(
      find.bySemanticsLabel('LaTeX source editor'),
      'Most recent edit',
    );
    await tester.pump();

    expect(store.byId('persisted')?.source, 'Most recent edit');
    await store.flush();
    expect(find.text('Saved locally'), findsOneWidget);
  });

  testWidgets('undo after switching documents stays within the new one', (
    tester,
  ) async {
    final store = DocumentStore.inMemory(
      documents: <ManyMathDocument>[
        ManyMathDocument(
          id: 'a',
          name: 'Alpha doc',
          source: 'ALPHA SOURCE',
          updatedAt: DateTime.utc(2026),
        ),
        ManyMathDocument(
          id: 'b',
          name: 'Beta doc',
          source: 'BETA SOURCE',
          updatedAt: DateTime.utc(2026),
        ),
      ],
    );
    await pumpEditor(tester, store: store);
    final editor = find.bySemanticsLabel('LaTeX source editor');
    String text() =>
        tester.widget<EditableText>(find.byType(EditableText)).controller.text;
    expect(text(), 'ALPHA SOURCE');

    await tester.enterText(editor, 'ALPHA EDITED');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Beta doc').last);
    await tester.pumpAndSettle();
    expect(text(), 'BETA SOURCE');

    // The editor keeps an undo history per EditableText; it must not reach
    // back into the previous document's buffer.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(editor);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(text(), 'BETA SOURCE');
    expect(store.byId('b')?.source, 'BETA SOURCE');
    expect(store.byId('a')?.source, 'ALPHA EDITED');
  });

  testWidgets('formatting shortcuts only edit a focused source editor', (
    tester,
  ) async {
    final store = await pumpEditor(
      tester,
      size: const Size(700, 900),
      initialSource: 'hello world',
    );
    Future<void> controlB() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    final surfaces = find.byWidgetPredicate(
      (widget) => widget is MSegmentedControl<EditorSurface>,
    );
    // The compact layout is showing the preview; the source is hidden.
    await tester.tap(
      find.descendant(of: surfaces, matching: find.text('Preview')),
    );
    await tester.pump();
    await controlB();
    expect(store.documents.single.source, 'hello world');

    await tester.tap(
      find.descendant(of: surfaces, matching: find.text('Source')),
    );
    await tester.pump();
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 5,
    );
    await tester.pump();
    await controlB();
    expect(store.documents.single.source, r'\textbf{hello} world');
  });

  testWidgets('formatting snippets wrap the current editor selection', (
    tester,
  ) async {
    final store = await pumpEditor(tester, initialSource: 'hello world');
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 5,
    );

    await tester.tap(find.bySemanticsLabel('Bold'));
    await tester.pump();

    expect(editable.controller.text, r'\textbf{hello} world');
    expect(store.documents.single.source, r'\textbf{hello} world');
  });

  testWidgets('a formula problem selects its exact source range', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      initialSource: r'Before $broken$ after',
      formulaChecker: (_) => const <FormulaIssue>[
        FormulaIssue(
          latex: 'broken',
          message: 'Unknown command',
          displayMode: false,
          errorStart: 8,
          errorEnd: 14,
        ),
      ],
    );

    expect(find.bySemanticsLabel('Preview status: 1 problem'), findsOneWidget);
    await tester.tap(
      find.bySemanticsLabel(
        'Jump to problem: Unknown command. Formula: broken',
      ),
    );
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(
      editable.controller.selection,
      const TextSelection(baseOffset: 8, extentOffset: 14),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('editing clears formula problems with now-stale offsets', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      initialSource: r'Before $broken$ after',
      formulaChecker: (_) => const <FormulaIssue>[
        FormulaIssue(
          latex: 'broken',
          message: 'Unknown command',
          displayMode: false,
          errorStart: 8,
          errorEnd: 14,
        ),
      ],
    );
    expect(
      find.bySemanticsLabel(
        'Jump to problem: Unknown command. Formula: broken',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.bySemanticsLabel('LaTeX source editor'),
      'Entirely different source',
    );
    await tester.pump();

    expect(find.text('Changes pending'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Jump to problem: Unknown command. Formula: broken',
      ),
      findsNothing,
    );
  });

  testWidgets('a collapsed problems panel stays collapsed across renders', (
    tester,
  ) async {
    var broken = true;
    await pumpEditor(
      tester,
      initialSource: r'Before $broken$ after',
      formulaChecker: (_) => broken
          ? const <FormulaIssue>[
              FormulaIssue(
                latex: 'broken',
                message: 'Unknown command',
                displayMode: false,
                errorStart: 8,
                errorEnd: 14,
              ),
            ]
          : const <FormulaIssue>[],
    );
    final jump = find.bySemanticsLabel(
      'Jump to problem: Unknown command. Formula: broken',
    );
    expect(jump, findsOneWidget, reason: 'new problems open the panel');

    Future<void> editAndRender(String source) async {
      await tester.enterText(
        find.bySemanticsLabel('LaTeX source editor'),
        source,
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settleRender(tester);
    }

    await tester.tap(find.bySemanticsLabel('Problems panel, 1 problems'));
    await tester.pump();
    expect(jump, findsNothing);
    await editAndRender(r'Before $broken$ still');
    expect(jump, findsNothing, reason: 'the reader collapsed it');

    broken = false;
    await editAndRender('Fixed');
    expect(find.bySemanticsLabel('Problems panel, none'), findsOneWidget);
    broken = true;
    await editAndRender(r'Broken $broken$ again');
    expect(jump, findsOneWidget, reason: 'problems are new again');
  });

  PreviewTheme previewTheme(WidgetTester tester) =>
      tester.widget<DocumentView>(find.byType(DocumentView)).previewTheme;

  Future<void> tapAppThemeToggle(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pump();
  }

  testWidgets('app theme toggle restyles the app and preview together', (
    tester,
  ) async {
    await pumpEditor(tester);
    expect(previewTheme(tester), PreviewTheme.light);

    await tapAppThemeToggle(tester, 'Use dark theme');
    expect(previewTheme(tester), PreviewTheme.dark);
    await tapAppThemeToggle(tester, 'Use terminal theme');
    expect(previewTheme(tester), PreviewTheme.terminal);
    await tapAppThemeToggle(tester, 'Use night theme');
    expect(previewTheme(tester), PreviewTheme.night);
    await tapAppThemeToggle(tester, 'Use light theme');
    expect(previewTheme(tester), PreviewTheme.light);

    // The preview pane has no toggle of its own left behind.
    expect(find.bySemanticsLabel(RegExp('Preview theme:')), findsNothing);
  });

  testWidgets('app theme toggle cycles light, dark, terminal, and night', (
    tester,
  ) async {
    await pumpEditor(tester);
    MWidgetsApp app() => tester.widget<MWidgetsApp>(find.byType(MWidgetsApp));

    Future<void> tap(String label) async {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
    }

    expect(app().themeMode, MThemeMode.light);

    await tap('Use dark theme');
    expect(app().themeMode, MThemeMode.dark);

    await tap('Use terminal theme');
    expect(app().themeMode, MThemeMode.light);
    expect(app().theme?.colors.foreground, manyMathTerminalGreen);

    await tap('Use night theme');
    expect(app().themeMode, MThemeMode.light);
    expect(app().theme?.colors.foreground, manyMathNightRed);

    await tap('Use light theme');
    expect(app().themeMode, MThemeMode.light);
    expect(app().theme?.colors.foreground, isNot(manyMathNightRed));
    expect(app().theme?.colors.foreground, isNot(manyMathTerminalGreen));
  });

  testWidgets('source and preview fonts change independently', (tester) async {
    await pumpEditor(tester);

    DocumentView documentView() =>
        tester.widget<DocumentView>(find.byType(DocumentView));
    EditableText editor() =>
        tester.widget<EditableText>(find.byType(EditableText));

    expect(documentView().fontFamily, 'Latin Modern Roman');
    expect(editor().style.fontFamily, 'JetBrains Mono');

    await tester.tap(find.bySemanticsLabel(RegExp('Preview font:')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Georgia'));
    await tester.pumpAndSettle();

    expect(documentView().fontFamily, 'Georgia');
    expect(editor().style.fontFamily, 'JetBrains Mono');

    await tester.tap(find.byType(MSelect<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menlo').last);
    await tester.pumpAndSettle();

    expect(editor().style.fontFamily, 'Menlo');
    expect(documentView().fontFamily, 'Georgia');
  });

  testWidgets('preview zoom tops out at 300 percent', (tester) async {
    await pumpEditor(tester);

    Future<void> zoomIn() async {
      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.pump();
    }

    for (var i = 0; i < 25; i++) {
      await zoomIn();
    }
    expect(find.text('300%'), findsOneWidget);

    // The button disables at the ceiling: another tap changes nothing.
    await zoomIn();
    expect(find.text('300%'), findsOneWidget);
  });

  testWidgets('preview zoom bottoms out at 70 percent without a dead tap', (
    tester,
  ) async {
    await pumpEditor(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Zoom out'));
      await tester.pump();
    }
    expect(find.text('70%'), findsOneWidget);
    // Three 0.1 steps accumulate float error; the limit must still disable
    // the button rather than leave a tap that only clamps.
    final button = tester.widget<MButton>(
      find.ancestor(
        of: find.bySemanticsLabel('Zoom out'),
        matching: find.byType(MButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('maximizing leaves a hidden Documents pane alone', (
    tester,
  ) async {
    // Below the Documents breakpoint the pane is not in the layout.
    await pumpEditor(tester, size: const Size(1000, 800));
    expect(find.text('Documents'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Maximize source'));
    await tester.pump();
    expect(find.bySemanticsLabel('Restore split view'), findsOneWidget);

    // Widening brings the Documents pane in open, not as a minimized strip
    // the user never asked for; only the preview stays minimized.
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump();
    await tester.pump();
    expect(find.text('Documents'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('expand-Documents-pane')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('expand-Preview-pane')),
      findsOneWidget,
    );
  });

  testWidgets('page setup switches the preview between scroll and pages', (
    tester,
  ) async {
    await pumpEditor(tester);
    DocumentView documentView() =>
        tester.widget<DocumentView>(find.byType(DocumentView));

    // Continuous by default: no page size, and US Letter preselected.
    expect(documentView().pageSize, isNull);
    expect(
      find.bySemanticsLabel('Page setup: Continuous layout, US Letter'),
      findsOneWidget,
    );

    await tester.tap(
      find.bySemanticsLabel(RegExp('Page setup: Continuous layout')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pages'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(documentView().pageSize, PageSize.usLetter);
    expect(find.bySemanticsLabel(RegExp('Page 1 of ')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('Page setup: Pages')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuous'));
    await tester.pumpAndSettle();

    expect(documentView().pageSize, isNull);
  });
}
