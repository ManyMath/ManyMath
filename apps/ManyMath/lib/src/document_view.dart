import 'package:flutter/widgets.dart';
import 'package:manyui/manyui.dart';
import 'package:ratex_flutter/ratex_flutter.dart';

import 'latex_document.dart';

class DocumentView extends StatelessWidget {
  const DocumentView({
    required this.blocks,
    this.macroPreamble = '',
    this.zoom = 1,
    super.key,
  });

  final List<DocBlock> blocks;

  /// `\providecommand`/`\def` statements collected from the whole document
  /// (see `extractMacroPreamble`), prepended to every formula so RaTeX's
  /// macro expander can resolve the paper's own macros.
  final String macroPreamble;
  final double zoom;

  double get _bodySize => 16 * zoom;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Rendered document preview',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final canvasPadding = compact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 20)
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 30);
          final paperPadding = compact ? 24.0 : 48.0;
          return ListView(
            padding: canvasPadding,
            children: <Widget>[
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 760),
                  padding: EdgeInsets.all(paperPadding),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFFD9DEDB)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      color: const Color(0xFF18201C),
                      fontSize: _bodySize,
                      height: 1.55,
                      fontFamily: 'Georgia',
                      fontFamilyFallback: const <String>[
                        'Times New Roman',
                        'Noto Serif',
                        'serif',
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (blocks.isEmpty)
                          Text(
                            'No rendered content',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: const Color(0xFF64716B)),
                          ),
                        for (final block in blocks) _buildBlock(context, block),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _formula(
    BuildContext context,
    String latex, {
    required double fontSize,
    bool displayMode = true,
  }) {
    return RatexMath(
      macroPreamble + latex,
      fontSize: fontSize,
      displayMode: displayMode,
      color: const Color(0xFF18201C),
      semanticLabel: 'Math formula: $latex',
      loadingBuilder: (_) => SizedBox(height: fontSize),
      errorBuilder: (_, error) => Text(
        'Formula error: ${error.message}',
        style: TextStyle(
          color: MTheme.of(context).colors.destructive,
          fontFamily: 'ui-monospace',
          fontSize: fontSize * 0.68,
        ),
      ),
    );
  }

  Widget _buildBlock(BuildContext context, DocBlock block) {
    switch (block) {
      case TitleBlock():
        Widget metadata(
          String source,
          List<int>? sourceMap,
          double fontSize,
          TextStyle style,
        ) {
          return Text.rich(
            TextSpan(
              children: _inlineSpans(
                context,
                parseInline(source, sourceMap: sourceMap),
                fontSize,
              ),
            ),
            textAlign: TextAlign.center,
            style: style,
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 24 * zoom),
          child: Column(
            children: <Widget>[
              if (block.title != null)
                Semantics(
                  header: true,
                  headingLevel: 2,
                  child: metadata(
                    block.title!,
                    block.titleSourceMap,
                    28 * zoom,
                    TextStyle(
                      fontSize: 28 * zoom,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (block.author != null)
                Padding(
                  padding: EdgeInsets.only(top: 8 * zoom),
                  child: metadata(
                    block.author!,
                    block.authorSourceMap,
                    _bodySize,
                    TextStyle(fontSize: _bodySize),
                  ),
                ),
              if (block.date != null)
                Padding(
                  padding: EdgeInsets.only(top: 4 * zoom),
                  child: metadata(
                    block.date!,
                    block.dateSourceMap,
                    _bodySize,
                    TextStyle(fontSize: _bodySize, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        );
      case HeadingBlock():
        final size = switch (block.level) {
          1 => 24.0 * zoom,
          2 => 20.0 * zoom,
          _ => 17.0 * zoom,
        };
        return Semantics(
          header: true,
          headingLevel: switch (block.level) {
            1 => 3,
            2 => 4,
            _ => 5,
          },
          child: Padding(
            padding: EdgeInsets.only(top: 20 * zoom, bottom: 8 * zoom),
            child: Text.rich(
              TextSpan(children: _inlineSpans(context, block.spans, size)),
              style: TextStyle(
                fontSize: size,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      case ParagraphBlock():
        return Padding(
          padding: EdgeInsets.only(bottom: 12 * zoom),
          child: Text.rich(
            TextSpan(children: _inlineSpans(context, block.spans, _bodySize)),
          ),
        );
      case DisplayMathBlock():
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 12 * zoom),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _formula(context, block.latex, fontSize: _bodySize * 1.25),
            ),
          ),
        );
      case ListBlock():
        return Padding(
          padding: EdgeInsets.only(bottom: 12 * zoom, left: 8 * zoom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final (index, item) in block.items.indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: 4 * zoom),
                  child: block.style == ListStyle.description
                      ? Text.rich(
                          TextSpan(
                            children: _inlineSpans(context, item, _bodySize),
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: 28 * zoom,
                              child: Text(
                                block.style == ListStyle.numbered
                                    ? '${index + 1}.'
                                    : '•',
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(width: 8 * zoom),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: _inlineSpans(
                                    context,
                                    item,
                                    _bodySize,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        );
      case CodeBlock():
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8 * zoom),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(12 * zoom),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFD9DEDB)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                block.code,
                style: TextStyle(
                  fontFamily: 'ui-monospace',
                  fontSize: _bodySize * 0.85,
                  height: 1.4,
                ),
              ),
            ),
          ),
        );
    }
  }

  List<InlineSpan> _inlineSpans(
    BuildContext context,
    List<DocInline> spans,
    double fontSize,
  ) {
    return <InlineSpan>[
      for (final span in spans)
        switch (span) {
          TextRun() => TextSpan(
            text: span.text,
            style: TextStyle(
              fontWeight: span.bold ? FontWeight.w700 : null,
              fontStyle: span.italic ? FontStyle.italic : null,
              fontFamily: span.monospace ? 'ui-monospace' : null,
              decoration: span.underline ? TextDecoration.underline : null,
            ),
          ),
          InlineMath() => WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _formula(
              context,
              span.latex,
              fontSize: fontSize,
              displayMode: false,
            ),
          ),
        },
    ];
  }
}
