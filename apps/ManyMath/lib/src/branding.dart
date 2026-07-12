import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';

class ManyMathMark extends StatelessWidget {
  const ManyMathMark({this.size = 32, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = MTheme.of(context);
    return Semantics(
      image: true,
      label: 'ManyMath',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.primary,
              borderRadius: BorderRadius.circular(size * 0.22),
            ),
            child: Center(
              child: Text(
                'Σ',
                style: TextStyle(
                  color: theme.colors.primaryForeground,
                  fontFamily: 'Georgia',
                  fontSize: size * 0.62,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
