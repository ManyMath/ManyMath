# Editor release and deferred review integration

`release/editor-without-review` is the standalone editor release line. It starts
at the last commit before the review dependency was introduced (`21f031d`) and
consolidates the later editor, parser, printing, export, dependency and font-notice
improvements from `094dadb67805174e399408e4f844f3f34f886926` into one editor-only
commit. The optional review implementation and its schema/fixture dependencies
are absent from this branch and were not merged into its ancestry.

`feature/review-on-editor` is a direct child of that release tip. Its single
additional commit restores the deferred review integration, including its
private package pins, service discovery, source navigation, tests and fixtures.
Keep this branch private until its dependencies and content are approved.

The original fine-grained history remains on private `main` and on
`preservation/20261029-before-review-separation`. Neither existing main nor any
public ref was rewritten by this separation. The older public main already
contains some historical review integration; this split does not erase it.

To publish only the editor, select `release/editor-without-review` as the source
ref. Do not merge the old integrated main into that branch: doing so would bring
back the deferred ancestry. Future editor fixes can be made on the release line
and then merged or rebased into the child feature branch deliberately.

ManyUI uses public revision `d5b8881a8a582ef0f6f5989addd6ab1fd4ef144c`.
RaTeX uses published `ratex` and `ratex_dart` packages, locked to `0.0.1` in
`pubspec.lock`. The feature branch additionally
uses private review/schema sources. Existing bundled-paper disclosure decisions
are unchanged. GitHub pushes, public CI execution and deployment remain owner
operations.
