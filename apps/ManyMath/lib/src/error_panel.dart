import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';

import 'formula_check.dart';

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    required this.issues,
    required this.expanded,
    required this.onToggle,
    required this.onJump,
    super.key,
  });

  final List<FormulaIssue> issues;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<FormulaIssue> onJump;

  @override
  Widget build(BuildContext context) {
    final theme = MTheme.of(context);
    final hasIssues = issues.isNotEmpty;
    return ColoredBox(
      color: theme.colors.muted,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const MDivider(),
          Semantics(
            expanded: expanded,
            child: MListTile(
              semanticLabel: hasIssues
                  ? 'Problems panel, ${issues.length} problems'
                  : 'Problems panel, none',
              title: Text(
                hasIssues
                    ? 'Problem${issues.length == 1 ? '' : 's'} '
                          '(${issues.length})'
                    : 'No problems',
                style: theme.typography.caption.copyWith(
                  color: hasIssues
                      ? theme.colors.destructive
                      : theme.colors.mutedForeground,
                ),
              ),
              trailing: MIcon(
                expanded ? MIconData.chevronDown : MIconData.chevronRight,
                size: 14,
                color: theme.colors.mutedForeground,
                excludeFromSemantics: true,
              ),
              onTap: onToggle,
            ),
          ),
          if (expanded && hasIssues)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 168),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: issues.length,
                itemBuilder: (context, index) {
                  final issue = issues[index];
                  return MListTile(
                    semanticLabel:
                        'Jump to problem: ${issue.message}. '
                        'Formula: ${issue.latex.replaceAll('\n', ' ')}',
                    title: Text(
                      issue.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(
                        color: theme.colors.destructive,
                      ),
                    ),
                    subtitle: Text(
                      issue.latex.replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.code.copyWith(
                        fontSize: 11,
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                    onTap: () => onJump(issue),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
