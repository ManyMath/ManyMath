import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';
import 'package:ratex_flutter/ratex_flutter.dart';

import 'branding.dart';
import 'document_browser.dart';
import 'document_store.dart';
import 'document_view.dart';
import 'editor_toolbar.dart';
import 'error_panel.dart';
import 'formula_check.dart';
import 'latex_document.dart';
import 'templates.dart';
import 'tex_files.dart';

const double editorCompactBreakpoint = 780;
const double documentBrowserBreakpoint = 1100;

enum EditorSurface { source, preview }

class EditorPage extends StatefulWidget {
  const EditorPage({
    required this.store,
    required this.themeMode,
    required this.onToggleTheme,
    this.engineInitializer,
    this.formulaChecker,
    this.persistentStorage = true,
    super.key,
  });

  final DocumentStore store;
  final MThemeMode themeMode;
  final ValueChanged<bool> onToggleTheme;
  final Future<void> Function()? engineInitializer;
  final List<FormulaIssue> Function(List<DocBlock>)? formulaChecker;
  final bool persistentStorage;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage>
    implements TextSelectionGestureDetectorBuilderDelegate {
  late ManyMathDocument _document;
  late final TextEditingController _source;
  final FocusNode _sourceFocus = FocusNode(debugLabel: 'LaTeX source editor');
  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();
  @override
  bool get forcePressEnabled => false;
  @override
  bool get selectionEnabled => true;
  late final TextSelectionGestureDetectorBuilder _selectionGestures =
      TextSelectionGestureDetectorBuilder(delegate: this);

  List<DocBlock> _blocks = const <DocBlock>[];
  List<FormulaIssue> _issues = const <FormulaIssue>[];
  ({int words, int formulas}) _counts = (words: 0, formulas: 0);
  EditorSurface _compactSurface = EditorSurface.source;
  bool _engineLoading = true;
  bool _engineReady = false;
  bool _changesPending = false;
  bool _documentsVisible = true;
  bool _problemsExpanded = false;
  bool _saving = false;
  String? _engineError;
  String? _saveError;
  double _previewZoom = 1;
  int? _lastRenderMilliseconds;
  var _saveRevision = 0;

  DocumentStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final documents = store.documents;
    _document =
        store.byId(store.lastOpenedId ?? '') ??
        (documents.isNotEmpty
            ? documents.first
            : store.create(name: 'Untitled', source: blankTemplate.source));
    store.lastOpenedId = _document.id;
    _source = TextEditingController(text: _document.source);
    store.onPersistError = _handlePersistError;
    if (!widget.persistentStorage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showMToast(
          context,
          semanticLabel: 'Local storage is unavailable',
          builder: (_) => const Text(
            'Local storage is unavailable. This is a temporary session.',
          ),
        );
      });
    }
    _initializeEngine();
  }

  @override
  void dispose() {
    if (store.onPersistError == _handlePersistError) {
      store.onPersistError = null;
    }
    store.updateSource(_document.id, _source.text);
    unawaited(store.flush().catchError((_) {}));
    _source.dispose();
    _sourceFocus.dispose();
    super.dispose();
  }

  void _handlePersistError(DocumentPersistenceException error, StackTrace _) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = error.toString();
    });
    showMToast(
      context,
      semanticLabel: 'Document could not be saved',
      builder: (_) => const Text('Could not save the local document.'),
    );
  }

  Future<void> _initializeEngine() async {
    setState(() {
      _engineLoading = true;
      _engineError = null;
    });
    try {
      await (widget.engineInitializer ?? RatexFlutter.ensureInitialized)();
      if (!mounted) return;
      setState(() {
        _engineLoading = false;
        _engineReady = true;
      });
      _render();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _engineLoading = false;
        _engineReady = false;
        _engineError = '$error';
      });
    }
  }

  void _sourceChanged(String source) {
    store.updateSource(_document.id, source);
    _document = store.byId(_document.id) ?? _document;
    final revision = ++_saveRevision;
    setState(() {
      _changesPending = true;
      _issues = const <FormulaIssue>[];
      _problemsExpanded = false;
      _saving = true;
      _saveError = null;
    });
    unawaited(_confirmSaved(revision));
  }

  Future<void> _confirmSaved(int revision) async {
    try {
      await store.flush();
    } on DocumentPersistenceException {
      return;
    }
    if (!mounted || revision != _saveRevision) return;
    setState(() => _saving = false);
  }

  void _render() {
    if (!_engineReady) return;
    final stopwatch = Stopwatch()..start();
    final blocks = parseLatexDocument(_source.text);
    final issues = (widget.formulaChecker ?? checkFormulas)(blocks);
    stopwatch.stop();
    setState(() {
      if (issues.isNotEmpty && _issues.isEmpty) _problemsExpanded = true;
      _blocks = blocks;
      _issues = issues;
      _counts = countDocument(blocks);
      _changesPending = false;
      _lastRenderMilliseconds = stopwatch.elapsedMilliseconds;
    });
  }

  Future<void> _saveNow() async {
    store.updateSource(_document.id, _source.text);
    store.save();
    final revision = ++_saveRevision;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    await _confirmSaved(revision);
  }

  void _jumpTo(FormulaIssue issue) {
    final selection = issue.selection;
    if (selection == null) return;
    final start = selection.$1.clamp(0, _source.text.length);
    final end = selection.$2.clamp(start, _source.text.length);
    setState(() => _compactSurface = EditorSurface.source);
    _source.selection = TextSelection(baseOffset: start, extentOffset: end);
    _sourceFocus.requestFocus();
  }

  void _applySnippet(Snippet snippet) {
    _source.value = applySnippet(_source.value, snippet);
    _sourceChanged(_source.text);
    _sourceFocus.requestFocus();
  }

  Future<void> _copySource() async {
    await Clipboard.setData(ClipboardData(text: _source.text));
    if (!mounted) return;
    showMToast(
      context,
      semanticLabel: 'LaTeX source copied',
      builder: (_) => const Text('LaTeX source copied'),
    );
  }

  void _setZoom(double next) {
    setState(() => _previewZoom = next.clamp(0.7, 1.4));
  }

  void _selectDocument(ManyMathDocument document) {
    if (document.id == _document.id) return;
    store.updateSource(_document.id, _source.text);
    setState(() {
      _document = document;
      _source.value = TextEditingValue(
        text: document.source,
        selection: const TextSelection.collapsed(offset: 0),
      );
      _issues = const <FormulaIssue>[];
      _changesPending = false;
      _saving = false;
      _saveError = null;
    });
    store.lastOpenedId = document.id;
    _render();
  }

  Future<void> _createDocument() async {
    var name = 'Untitled';
    var template = blankTemplate;
    final created = await showMDialog<bool>(
      context,
      semanticLabel: 'Create a document',
      builder: (dialogContext) => MDialogContent(
        title: 'New document',
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const MLabel('Document name'),
              const SizedBox(height: 7),
              MTextField(
                initialValue: name,
                autofocus: MediaQuery.sizeOf(dialogContext).width >= 640,
                semanticLabel: 'Document name',
                onChanged: (value) => name = value,
              ),
              const SizedBox(height: 14),
              const MLabel('Template'),
              const SizedBox(height: 7),
              MSelect<DocumentTemplate>(
                semanticLabel: 'Document template',
                initialValue: template,
                items: <MSelectItem<DocumentTemplate>>[
                  for (final item in documentTemplates)
                    MSelectItem(value: item, label: item.name),
                ],
                onChanged: (value) {
                  if (value != null) template = value;
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          MButton(
            variant: MButtonVariant.ghost,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          MButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created != true || !mounted) return;
    _selectDocument(store.create(name: name, source: template.source));
  }

  Future<void> _renameDocument(ManyMathDocument document) async {
    var name = document.name;
    final rename = await showMDialog<bool>(
      context,
      semanticLabel: 'Rename ${document.name}',
      builder: (dialogContext) => MDialogContent(
        title: 'Rename document',
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: MTextField(
            initialValue: document.name,
            autofocus: MediaQuery.sizeOf(dialogContext).width >= 640,
            semanticLabel: 'Document name',
            onChanged: (value) => name = value,
            onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
          ),
        ),
        actions: <Widget>[
          MButton(
            variant: MButtonVariant.ghost,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          MButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (rename != true || !mounted || !store.rename(document.id, name)) return;
    if (document.id == _document.id) {
      setState(() => _document = store.byId(document.id)!);
    }
  }

  Future<void> _deleteDocument(ManyMathDocument document) async {
    final confirmed = await showMConfirmDialog(
      context,
      title: 'Delete document?',
      message: 'Delete "${document.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmVariant: MButtonVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    store.remove(document.id);
    if (document.id != _document.id) return;
    final remaining = store.documents;
    _selectDocument(
      remaining.isNotEmpty
          ? remaining.first
          : store.create(name: 'Untitled', source: blankTemplate.source),
    );
  }

  void _handleDocumentAction(ManyMathDocument document, DocumentAction action) {
    switch (action) {
      case DocumentAction.rename:
        unawaited(_renameDocument(document));
      case DocumentAction.duplicate:
        store.updateSource(_document.id, _source.text);
        final duplicate = store.duplicate(document.id);
        if (duplicate != null) _selectDocument(duplicate);
      case DocumentAction.delete:
        unawaited(_deleteDocument(document));
    }
  }

  Future<void> _importTex() async {
    try {
      final imported = await openTexFile();
      if (imported == null || !mounted) return;
      final document = store.create(
        name: imported.name,
        source: imported.contents,
      );
      _selectDocument(document);
      showMToast(
        context,
        semanticLabel: 'LaTeX document imported',
        builder: (_) => Text('Imported ${imported.name}'),
      );
    } on Object catch (error) {
      if (!mounted) return;
      showMToast(
        context,
        semanticLabel: 'LaTeX import failed',
        builder: (_) => Text('Could not import: $error'),
      );
    }
  }

  Future<void> _exportTex() async {
    await _saveNow();
    try {
      final destination = await saveTexFile(_document.name, _source.text);
      if (destination == null || !mounted) return;
      showMToast(
        context,
        semanticLabel: 'LaTeX document exported',
        builder: (_) => Text('Exported $destination'),
      );
    } on Object catch (error) {
      if (!mounted) return;
      showMToast(
        context,
        semanticLabel: 'LaTeX export failed',
        builder: (_) => Text('Could not export: $error'),
      );
    }
  }

  Future<void> _showDocuments() async {
    final viewport = MediaQuery.sizeOf(context);
    if (viewport.width >= documentBrowserBreakpoint) {
      setState(() => _documentsVisible = !_documentsVisible);
      return;
    }
    final isPhone = viewport.width < 640;
    VoidCallback? afterClose;
    await showMSheet<void>(
      context,
      anchor: isPhone ? MSheetAnchor.bottom : MSheetAnchor.start,
      semanticLabel: 'Documents',
      builder: (sheetContext) {
        void close() => Navigator.of(sheetContext).pop();

        void closeThen(VoidCallback action) {
          afterClose = action;
          close();
        }

        return SizedBox(
          height: isPhone ? math.min(560, viewport.height * 0.72) : null,
          child: DocumentBrowser(
            store: store,
            selectedId: _document.id,
            onClose: close,
            onCreate: () => closeThen(() => unawaited(_createDocument())),
            onSelect: (document) => closeThen(() => _selectDocument(document)),
            onAction: (document, action) =>
                closeThen(() => _handleDocumentAction(document, action)),
          ),
        );
      },
    );
    if (mounted) afterClose?.call();
  }

  Future<void> _showAbout() {
    return showMDialog<void>(
      context,
      semanticLabel: 'About ManyMath',
      builder: (dialogContext) => MDialogContent(
        title: 'About ManyMath',
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: const Text(
            'ManyMath is a focused LaTeX mathematics editor from ManyMath LLC. '
            'Documents stay on this device and can be imported or exported as '
            '.tex files. The RaTeX engine renders the preview locally.',
          ),
        ),
        actions: <Widget>[
          MButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String get _renderStatus {
    if (_engineLoading) return 'Loading engine';
    if (_engineError != null) return 'Renderer unavailable';
    if (_changesPending) return 'Changes pending';
    if (_issues.isNotEmpty) {
      return '${_issues.length} problem${_issues.length == 1 ? '' : 's'}';
    }
    return 'Rendered';
  }

  @override
  Widget build(BuildContext context) {
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final currentlyDark =
        widget.themeMode == MThemeMode.dark ||
        (widget.themeMode == MThemeMode.system && platformDark);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _render,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _render,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          unawaited(_saveNow());
        },
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          unawaited(_saveNow());
        },
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          _applySnippet(snippetBold);
        },
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
          _applySnippet(snippetBold);
        },
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
          _applySnippet(snippetItalic);
        },
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () {
          _applySnippet(snippetItalic);
        },
        const SingleActivator(LogicalKeyboardKey.keyM, control: true): () {
          _applySnippet(snippetInlineMath);
        },
        const SingleActivator(LogicalKeyboardKey.keyM, meta: true): () {
          _applySnippet(snippetInlineMath);
        },
      },
      child: Focus(
        autofocus: true,
        child: MScaffold(
          header: MAppHeader(
            title: 'ManyMath',
            headingLevel: 1,
            compactBreakpoint: 780,
            subtitle: _document.name,
            leading: const ExcludeSemantics(child: ManyMathMark()),
            status: Semantics(
              container: true,
              liveRegion: true,
              label: 'Preview status: $_renderStatus',
              excludeSemantics: true,
              child: MBadge(
                variant: _engineError == null && _issues.isEmpty
                    ? MBadgeVariant.secondary
                    : MBadgeVariant.destructive,
                child: Text(_renderStatus),
              ),
            ),
            actions: <Widget>[
              MIconButton(
                icon: MIconData.folder,
                label:
                    MediaQuery.sizeOf(context).width >=
                            documentBrowserBreakpoint &&
                        _documentsVisible
                    ? 'Hide documents'
                    : 'Open documents',
                size: MButtonSize.sm,
                onPressed: _showDocuments,
              ),
              MButton(
                onPressed: _engineReady ? _render : null,
                size: MButtonSize.sm,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    MIcon(MIconData.play, size: 15, excludeFromSemantics: true),
                    SizedBox(width: 7),
                    Text('Render'),
                  ],
                ),
              ),
              _FileMenu(
                onCreate: _createDocument,
                onRename: () => _renameDocument(_document),
                onDuplicate: () =>
                    _handleDocumentAction(_document, DocumentAction.duplicate),
                onImport: _importTex,
                onExport: _exportTex,
                onCopy: _copySource,
                onAbout: _showAbout,
              ),
              MIconButton(
                icon: currentlyDark ? MIconData.sun : MIconData.moon,
                label: currentlyDark ? 'Use light theme' : 'Use dark theme',
                size: MButtonSize.sm,
                onPressed: () => widget.onToggleTheme(currentlyDark),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final showDocuments =
                  constraints.maxWidth >= documentBrowserBreakpoint &&
                  _documentsVisible;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (showDocuments) ...<Widget>[
                    SizedBox(
                      width: 244,
                      child: DocumentBrowser(
                        store: store,
                        selectedId: _document.id,
                        onSelect: _selectDocument,
                        onCreate: _createDocument,
                        onAction: _handleDocumentAction,
                      ),
                    ),
                    const MDivider(orientation: MDividerOrientation.vertical),
                  ],
                  Expanded(
                    child: constraints.maxWidth < editorCompactBreakpoint
                        ? _buildCompactWorkspace()
                        : _buildSplitWorkspace(),
                  ),
                ],
              );
            },
          ),
          footer: _StatusBar(
            counts: _counts,
            characterCount: _source.text.length,
            renderMilliseconds: _lastRenderMilliseconds,
            saving: _saving,
            saveError: _saveError,
            persistentStorage: widget.persistentStorage,
            issueCount: _issues.length,
            onToggleProblems: () =>
                setState(() => _problemsExpanded = !_problemsExpanded),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactWorkspace() {
    final sourcePane = _buildSourcePane();
    final previewPane = _buildPreviewPane();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: MSegmentedControl<EditorSurface>(
            value: _compactSurface,
            fullWidth: true,
            onChanged: (value) => setState(() => _compactSurface = value),
            items: const <MSegmentedItem<EditorSurface>>[
              MSegmentedItem(value: EditorSurface.source, label: 'Source'),
              MSegmentedItem(value: EditorSurface.preview, label: 'Preview'),
            ],
          ),
        ),
        const MDivider(),
        Expanded(
          child: IndexedStack(
            index: _compactSurface.index,
            children: <Widget>[sourcePane, previewPane],
          ),
        ),
      ],
    );
  }

  Widget _buildSplitWorkspace() {
    final split = store.splitRatio.clamp(0.3, 0.7);
    return MResizable(
      semanticLabel: 'Source and preview pane sizes',
      initialSizes: <double>[split, 1 - split],
      onChanged: (sizes) => store.splitRatio = sizes.first,
      children: <MResizableChild>[
        MResizableChild(
          id: 'source',
          minSize: 0.3,
          maxSize: 0.7,
          child: _buildSourcePane(),
        ),
        MResizableChild(
          id: 'preview',
          minSize: 0.3,
          maxSize: 0.7,
          child: _buildPreviewPane(),
        ),
      ],
    );
  }

  Widget _buildSourcePane() {
    final theme = MTheme.of(context);
    return ColoredBox(
      color: theme.colors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PaneHeader(
            title: 'Source',
            subtitle: texFileName(_document.name),
            actions: <Widget>[
              MIconButton(
                icon: MIconData.copy,
                label: 'Copy LaTeX source',
                size: MButtonSize.xs,
                onPressed: _copySource,
              ),
            ],
          ),
          const MDivider(),
          EditorToolbar(onApply: _applySnippet),
          const MDivider(),
          Expanded(
            child: Semantics(
              label: 'LaTeX source editor',
              textField: true,
              child: MouseRegion(
                cursor: SystemMouseCursors.text,
                child: _selectionGestures.buildGestureDetector(
                  behavior: HitTestBehavior.translucent,
                  child: ColoredBox(
                    color: theme.colors.card,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: EditableText(
                        key: editableTextKey,
                        controller: _source,
                        focusNode: _sourceFocus,
                        style: theme.typography.code.copyWith(
                          color: theme.colors.foreground,
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                        cursorColor: theme.colors.foreground,
                        backgroundCursorColor: theme.colors.foreground,
                        selectionColor: theme.colors.ring.withValues(
                          alpha: 0.25,
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        expands: true,
                        onChanged: _sourceChanged,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_issues.isNotEmpty || MediaQuery.sizeOf(context).height >= 500)
            ErrorPanel(
              issues: _issues,
              expanded: _problemsExpanded,
              onToggle: () =>
                  setState(() => _problemsExpanded = !_problemsExpanded),
              onJump: _jumpTo,
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewPane() {
    return _PreviewPane(
      blocks: _blocks,
      zoom: _previewZoom,
      engineLoading: _engineLoading,
      engineError: _engineError,
      onRetry: _initializeEngine,
      onZoomOut: _previewZoom <= 0.7
          ? null
          : () => _setZoom(_previewZoom - 0.1),
      onResetZoom: _previewZoom == 1 ? null : () => _setZoom(1),
      onZoomIn: _previewZoom >= 1.4 ? null : () => _setZoom(_previewZoom + 0.1),
    );
  }
}

class _FileMenu extends StatefulWidget {
  const _FileMenu({
    required this.onCreate,
    required this.onRename,
    required this.onDuplicate,
    required this.onImport,
    required this.onExport,
    required this.onCopy,
    required this.onAbout,
  });

  final VoidCallback onCreate;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onCopy;
  final VoidCallback onAbout;

  @override
  State<_FileMenu> createState() => _FileMenuState();
}

class _FileMenuState extends State<_FileMenu> {
  final MPopoverController _menu = MPopoverController();

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MPopover(
      controller: _menu,
      semanticLabel: 'More actions',
      popoverBuilder: (context, close) => SizedBox(
        width: 208,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _item('New document', MIconData.plus, widget.onCreate, close),
            _item('Rename', MIconData.edit, widget.onRename, close),
            _item('Duplicate', MIconData.copy, widget.onDuplicate, close),
            _item('Import .tex', MIconData.folder, widget.onImport, close),
            _item('Export .tex', MIconData.fileText, widget.onExport, close),
            _item('Copy source', MIconData.copy, widget.onCopy, close),
            const MDivider(),
            _item('About ManyMath', MIconData.info, widget.onAbout, close),
          ],
        ),
      ),
      child: MIconButton(
        icon: MIconData.moreHorizontal,
        label: 'More actions',
        size: MButtonSize.sm,
        onPressed: _menu.toggle,
      ),
    );
  }

  Widget _item(
    String label,
    MIconData icon,
    VoidCallback action,
    VoidCallback close,
  ) {
    return MListTile(
      leading: MIcon(icon, size: 15, excludeFromSemantics: true),
      title: Text(label),
      onTap: () {
        close();
        action();
      },
    );
  }
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.title,
    required this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = MTheme.of(context);
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            Text(title, style: theme.typography.label),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                subtitle,
                style: theme.typography.caption.copyWith(
                  color: theme.colors.mutedForeground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({
    required this.blocks,
    required this.zoom,
    required this.engineLoading,
    required this.engineError,
    required this.onRetry,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onZoomIn,
  });

  final List<DocBlock> blocks;
  final double zoom;
  final bool engineLoading;
  final String? engineError;
  final VoidCallback onRetry;
  final VoidCallback? onZoomOut;
  final VoidCallback? onResetZoom;
  final VoidCallback? onZoomIn;

  @override
  Widget build(BuildContext context) {
    final theme = MTheme.of(context);
    final zoomLabel = '${(zoom * 100).round()}%';
    return ColoredBox(
      color: theme.colors.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ColoredBox(
            color: theme.colors.card,
            child: _PaneHeader(
              title: 'Preview',
              subtitle: engineLoading ? 'Starting renderer' : 'PDF-style page',
              actions: <Widget>[
                _SymbolButton(
                  symbol: '−',
                  label: 'Zoom out',
                  onPressed: onZoomOut,
                ),
                MButton(
                  semanticLabel: 'Reset preview zoom to 100 percent',
                  variant: MButtonVariant.ghost,
                  size: MButtonSize.xs,
                  onPressed: onResetZoom,
                  style: const MButtonStyleDelta(
                    minHeight: 32,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(zoomLabel),
                ),
                _SymbolButton(
                  symbol: '+',
                  label: 'Zoom in',
                  onPressed: onZoomIn,
                ),
              ],
            ),
          ),
          const MDivider(),
          Expanded(
            child: engineError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: MAlert(
                        title: 'Renderer unavailable',
                        variant: MAlertVariant.destructive,
                        message: engineError!,
                        maxWidth: 520,
                        actions: <Widget>[
                          MButton(
                            variant: MButtonVariant.outline,
                            onPressed: onRetry,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : engineLoading
                ? const Center(
                    child: MLoadingState(message: 'Loading typesetting engine'),
                  )
                : DocumentView(blocks: blocks, zoom: zoom),
          ),
        ],
      ),
    );
  }
}

class _SymbolButton extends StatelessWidget {
  const _SymbolButton({
    required this.symbol,
    required this.label,
    required this.onPressed,
  });

  final String symbol;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: MButton(
        semanticLabel: label,
        variant: MButtonVariant.ghost,
        size: MButtonSize.xs,
        onPressed: onPressed,
        style: const MButtonStyleDelta(minHeight: 32, padding: EdgeInsets.zero),
        child: Text(symbol, style: const TextStyle(fontSize: 18, height: 1)),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.counts,
    required this.characterCount,
    required this.renderMilliseconds,
    required this.saving,
    required this.saveError,
    required this.persistentStorage,
    required this.issueCount,
    required this.onToggleProblems,
  });

  final ({int words, int formulas}) counts;
  final int characterCount;
  final int? renderMilliseconds;
  final bool saving;
  final String? saveError;
  final bool persistentStorage;
  final int issueCount;
  final VoidCallback onToggleProblems;

  @override
  Widget build(BuildContext context) {
    final theme = MTheme.of(context);
    final saveLabel = !persistentStorage
        ? 'Temporary session'
        : saveError != null
        ? 'Save failed'
        : saving
        ? 'Saving'
        : 'Saved locally';
    final details = StringBuffer(
      '${counts.words} words  ·  ${counts.formulas} formulas  ·  '
      '$characterCount characters',
    );
    if (renderMilliseconds != null) {
      details.write('  ·  parsed in ${renderMilliseconds}ms');
    }
    final caption = theme.typography.caption.copyWith(
      color: theme.colors.mutedForeground,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        return Row(
          children: <Widget>[
            MBadge(
              variant: persistentStorage && saveError == null
                  ? MBadgeVariant.secondary
                  : MBadgeVariant.destructive,
              child: Text(saveLabel),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                compact
                    ? '${counts.words} words  ·  '
                          '${counts.formulas} formulas'
                          '${issueCount == 0 ? '' : '  ·  '
                                    '$issueCount problem${issueCount == 1 ? '' : 's'}'}'
                    : details.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: caption,
              ),
            ),
            if (!compact) ...<Widget>[
              const SizedBox(width: 10),
              MButton(
                semanticLabel: issueCount == 0
                    ? 'No formula problems'
                    : '$issueCount formula problems',
                variant: MButtonVariant.ghost,
                size: MButtonSize.xs,
                onPressed: onToggleProblems,
                child: Text(
                  issueCount == 0
                      ? 'No problems'
                      : '$issueCount problem${issueCount == 1 ? '' : 's'}',
                  style: caption.copyWith(
                    color: issueCount == 0
                        ? theme.colors.mutedForeground
                        : theme.colors.destructive,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
