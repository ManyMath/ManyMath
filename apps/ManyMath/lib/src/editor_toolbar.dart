import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';

class Snippet {
  const Snippet(this.label, this.before, this.after, this.placeholder);

  final String label;
  final String before;
  final String after;
  final String placeholder;
}

const snippetBold = Snippet('Bold', r'\textbf{', '}', 'bold text');
const snippetItalic = Snippet('Italic', r'\textit{', '}', 'italic text');
const snippetInlineMath = Snippet('Inline math', r'$', r'$', 'x');
const snippetDisplayMath = Snippet(
  'Display math',
  '\n\\[\n  ',
  '\n\\]\n',
  r'e^{i\pi} + 1 = 0',
);

const insertSnippets = <Snippet>[
  Snippet('Section', '\n\\section{', '}\n', 'Heading'),
  Snippet('Subsection', '\n\\subsection{', '}\n', 'Heading'),
  Snippet('Fraction', r'\frac{', '}{b}', 'a'),
  Snippet('Square root', r'\sqrt{', '}', 'x'),
  Snippet('Sum', r'\sum_{n=1}^{\infty} ', '', ''),
  Snippet('Integral', r'\int_{a}^{b} ', r' \, dx', 'f(x)'),
  Snippet('Binomial', r'\binom{', '}{k}', 'n'),
  Snippet(
    'Matrix',
    '\n\\[\n  \\begin{pmatrix}\n    ',
    ' \\\\\n    c & d\n  \\end{pmatrix}\n\\]\n',
    'a & b',
  ),
  Snippet(
    'Align environment',
    '\n\\begin{align}\n  ',
    ' \\\\\n  c &= d\n\\end{align}\n',
    'a &= b',
  ),
  Snippet(
    'Bulleted list',
    '\n\\begin{itemize}\n  \\item ',
    '\n  \\item Second\n\\end{itemize}\n',
    'First',
  ),
  Snippet(
    'Numbered list',
    '\n\\begin{enumerate}\n  \\item ',
    '\n  \\item Second\n\\end{enumerate}\n',
    'First',
  ),
];

TextEditingValue applySnippet(TextEditingValue value, Snippet snippet) {
  final selection = value.selection;
  final start = selection.isValid ? selection.start : value.text.length;
  final end = selection.isValid ? selection.end : value.text.length;
  final selected = value.text.substring(start, end);
  final inner = selected.isNotEmpty ? selected : snippet.placeholder;
  final replacement = '${snippet.before}$inner${snippet.after}';
  final text = value.text.replaceRange(start, end, replacement);
  final innerStart = start + snippet.before.length;
  return TextEditingValue(
    text: text,
    selection: selected.isNotEmpty || inner.isEmpty
        ? TextSelection.collapsed(offset: start + replacement.length)
        : TextSelection(
            baseOffset: innerStart,
            extentOffset: innerStart + inner.length,
          ),
  );
}

class EditorToolbar extends StatefulWidget {
  const EditorToolbar({required this.onApply, super.key});

  final ValueChanged<Snippet> onApply;

  @override
  State<EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<EditorToolbar> {
  final MPopoverController _insertMenu = MPopoverController();

  @override
  void dispose() {
    _insertMenu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = MTheme.of(context);
    final mono = theme.typography.code.copyWith(fontSize: 12);
    return ColoredBox(
      color: theme.colors.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _snippetButton(
                'B',
                tooltip: 'Bold',
                snippet: snippetBold,
                style: theme.typography.label.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              _snippetButton(
                'I',
                tooltip: 'Italic',
                snippet: snippetItalic,
                style: theme.typography.label.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              _snippetButton(
                r'$x$',
                tooltip: 'Inline math',
                snippet: snippetInlineMath,
                style: mono,
              ),
              _snippetButton(
                r'\[ \]',
                tooltip: 'Display math',
                snippet: snippetDisplayMath,
                style: mono,
              ),
              const SizedBox(width: 4),
              MPopover(
                controller: _insertMenu,
                semanticLabel: 'Insert LaTeX construct',
                popoverBuilder: (context, close) => SizedBox(
                  width: 220,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final snippet in insertSnippets)
                        MListTile(
                          title: Text(snippet.label),
                          onTap: () {
                            close();
                            widget.onApply(snippet);
                          },
                        ),
                    ],
                  ),
                ),
                child: MButton(
                  variant: MButtonVariant.ghost,
                  size: MButtonSize.sm,
                  onPressed: _insertMenu.toggle,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      MIcon(
                        MIconData.plus,
                        size: 14,
                        excludeFromSemantics: true,
                      ),
                      SizedBox(width: 6),
                      Text('Insert'),
                      SizedBox(width: 3),
                      MIcon(
                        MIconData.chevronDown,
                        size: 12,
                        excludeFromSemantics: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _snippetButton(
    String label, {
    required String tooltip,
    required Snippet snippet,
    required TextStyle style,
  }) {
    return MTooltip(
      message: tooltip,
      child: MButton(
        variant: MButtonVariant.ghost,
        size: MButtonSize.sm,
        semanticLabel: snippet.label,
        onPressed: () => widget.onApply(snippet),
        child: Text(label, style: style),
      ),
    );
  }
}
