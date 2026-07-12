import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/app.dart';
import 'package:manymath/src/document_store.dart';
import 'package:manymath/src/document_view.dart';
import 'package:manymath/src/editor_page.dart';
import 'package:manymath/src/formula_check.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manyui/manyui.dart';

void main() {
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
        initialThemeMode: MThemeMode.light,
        persistentStorage: persistentStorage,
      ),
    );
    await tester.pump();
    await tester.pump();
    return documentStore;
  }

  testWidgets('desktop workspace presents resizable source and preview panes', (
    tester,
  ) async {
    await pumpEditor(tester);

    expect(find.byType(MResizable), findsOneWidget);
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

    await tester.tap(find.text('Render'));
    await tester.pump();

    expect(find.text('Rendered'), findsOneWidget);
    expect(find.text('Second edit is longer'), findsNWidgets(2));
    expect(find.text('Original document'), findsNothing);
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
    await tester.pump();

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
    await tester.pump();

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
}
