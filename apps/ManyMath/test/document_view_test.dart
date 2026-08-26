import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/document_view.dart';
import 'package:manymath/src/latex_document.dart';
import 'package:manyui/manyui.dart';

void main() {
  testWidgets('zoom scales the whole page, margins included', (tester) async {
    const blocks = <DocBlock>[
      ParagraphBlock(<DocInline>[TextRun('Page body text')]),
    ];

    Future<double> contentWidthAt(double zoom) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MWidgetsApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: DocumentView(blocks: blocks, zoom: zoom),
          ),
        ),
      );
      final canvas = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(SizedBox),
      );
      return tester.getSize(canvas.first).width;
    }

    // At 100% the 760pt page plus its canvas padding determines the
    // canvas width.
    expect(await contentWidthAt(1), 760 + 48);

    // At 140% the page itself grows (760 * 1.4 = 1064, plus canvas
    // padding), outgrowing the viewport like a PDF zoom would.
    expect(await contentWidthAt(1.4), 760 * 1.4 + 48);
  });
}
