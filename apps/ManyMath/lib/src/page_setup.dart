/// Physical page geometry shared by the paged preview and printing.
///
/// Dimensions are CSS pixels at 96 dpi — the same unit the preview's
/// page-level zoom scales — so US Letter is 816x1056 and A4 is 794x1123.
/// The default is US Letter: most of the papers bundled with the editor
/// target it, and it is the safer guess for a North American print dialog.
enum PageSize {
  usLetter(width: 816, height: 1056, label: 'US Letter', cssName: 'Letter'),
  a4(width: 794, height: 1123, label: 'A4', cssName: 'A4');

  const PageSize({
    required this.width,
    required this.height,
    required this.label,
    required this.cssName,
  });

  final double width;
  final double height;

  /// Human-readable name for menus and semantic labels.
  final String label;

  /// The token CSS Paged Media understands in `@page { size: ... }`.
  final String cssName;
}

/// How the preview lays the document out: one continuous scroll (the
/// default, and how the editor has always rendered) or discrete pages.
enum PreviewLayout {
  continuous(label: 'Continuous'),
  pages(label: 'Pages');

  const PreviewLayout({required this.label});

  final String label;
}
