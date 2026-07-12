import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';

import 'document_store.dart';

enum DocumentAction { rename, duplicate, delete }

class DocumentBrowser extends StatelessWidget {
  const DocumentBrowser({
    required this.store,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    required this.onAction,
    this.onClose,
    super.key,
  });

  final DocumentStore store;
  final String selectedId;
  final ValueChanged<ManyMathDocument> onSelect;
  final VoidCallback onCreate;
  final void Function(ManyMathDocument, DocumentAction) onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = MTheme.of(context);
    return ColoredBox(
      color: theme.colors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      header: true,
                      headingLevel: 2,
                      child: Text('Documents', style: theme.typography.label),
                    ),
                  ),
                  MIconButton(
                    icon: MIconData.plus,
                    label: 'New document',
                    size: MButtonSize.xs,
                    onPressed: onCreate,
                  ),
                  if (onClose != null)
                    MIconButton(
                      icon: MIconData.close,
                      label: 'Close documents',
                      size: MButtonSize.xs,
                      onPressed: onClose,
                    ),
                ],
              ),
            ),
          ),
          const MDivider(),
          if (store.recoveryPayload != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: MAlert(
                title: 'Local data recovered',
                message:
                    'A damaged record was skipped. The original data remains '
                    'available for recovery.',
                variant: MAlertVariant.neutral,
              ),
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final documents = store.documents;
                if (documents.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: MEmptyState(
                        title: 'No documents yet',
                        description: 'Create a document to start writing.',
                        actions: <Widget>[
                          MButton(
                            onPressed: onCreate,
                            child: const Text('New document'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    final updated = relativeDocumentTime(document.updatedAt);
                    return MListTile(
                      selected: document.id == selectedId,
                      semanticLabel: 'Open ${document.name}, updated $updated',
                      title: Text(
                        document.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        updated,
                        style: theme.typography.caption.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                      trailing: _DocumentActions(
                        documentName: document.name,
                        onAction: (action) => onAction(document, action),
                      ),
                      onTap: () => onSelect(document),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentActions extends StatefulWidget {
  const _DocumentActions({required this.documentName, required this.onAction});

  final String documentName;
  final ValueChanged<DocumentAction> onAction;

  @override
  State<_DocumentActions> createState() => _DocumentActionsState();
}

class _DocumentActionsState extends State<_DocumentActions> {
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
      semanticLabel: 'Actions for ${widget.documentName}',
      popoverBuilder: (context, close) => SizedBox(
        width: 176,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _item('Rename', MIconData.edit, DocumentAction.rename, close),
            _item('Duplicate', MIconData.copy, DocumentAction.duplicate, close),
            _item('Delete', MIconData.trash, DocumentAction.delete, close),
          ],
        ),
      ),
      child: MIconButton(
        icon: MIconData.moreHorizontal,
        label: 'Actions for ${widget.documentName}',
        size: MButtonSize.xs,
        onPressed: _menu.toggle,
      ),
    );
  }

  Widget _item(
    String label,
    MIconData icon,
    DocumentAction action,
    VoidCallback close,
  ) {
    return MListTile(
      leading: MIcon(icon, size: 15, excludeFromSemantics: true),
      title: Text(label),
      onTap: () {
        close();
        widget.onAction(action);
      },
    );
  }
}

String relativeDocumentTime(DateTime time, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(time);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours} h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays} d ago';
  final local = time.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}'
      '-${local.day.toString().padLeft(2, '0')}';
}
