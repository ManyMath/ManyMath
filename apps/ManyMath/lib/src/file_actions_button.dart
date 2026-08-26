import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';

/// A document glyph with an ellipsis overlaid in the corner: the shared
/// button for per-file action menus (the header file menu and each row of
/// the Documents pane), so file operations never read as generic overflow.
class FileActionsButton extends StatelessWidget {
  const FileActionsButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

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
        child: const Stack(
          children: <Widget>[
            Center(
              child: MIcon(
                MIconData.fileText,
                size: 15,
                excludeFromSemantics: true,
              ),
            ),
            Positioned(
              right: 2,
              bottom: 3,
              child: MIcon(
                MIconData.moreHorizontal,
                size: 8,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
