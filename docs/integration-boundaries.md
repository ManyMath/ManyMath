# Editor and renderer boundaries

This branch contains the standalone ManyMath editor and website. ManyUI owns the
shared widgets; RaTeX owns the renderer and its Dart/Flutter packages. RaTeX uses
published `ratex` and `ratex_dart` packages from pub.dev. ManyUI uses a public
GitHub revision. The application remains `publish_to: none`; mirroring source is
separate from publishing packages or deploying the site.

`pubspec.lock` records resolved versions and hosted archive checksums. Run
`flutter pub get --enforce-lockfile` to enforce them, then
`python3 tool/integration.py` to check the resolved package source types/versions,
remaining Git pins and owned compatibility fixtures. There is no renderer Git
override or sibling directory dependency. `tool/integration-lock.json` records
these package contracts and fixture provenance separately; the renderer's
historical fixture revisions do not select its dependency source. Local path
overrides are for development only and fail the package contract check.

Use Flutter 3.47.2 / Dart 3.13.2, Rust 1.94.0, Python 3 and Node. Provision the
`wasm32-unknown-unknown` Rust target separately. Build helpers never install SDKs
or change shared defaults. Native renderer checks use an explicit `RATEX_LIB`
from `python3 tool/build_engine.py native`; without it the native cases report
skips. The web scripts build and check a local distribution without deploying it.

The application owns versioned renderer compatibility fixtures under
`apps/ManyMath/test/fixtures/integration/ratex`. Their bytes and license are
compared with the resolved published package.
The integration gate also verifies their recorded hashes; provenance records
the original Git revision and path without requiring that checkout. Dependency
updates must update manifests and lockfiles together and review fixture changes.

The existing bundled FROSTLASS/rage papers predate this separation. Their
previously recorded owner disclosure qualification is unchanged by this branch.
The additional optional review workspace and its integration fixtures are absent.

Private Gitea validation is in `.gitea/workflows/ci.yml`. GitHub's workflow remains
an owner-operated handoff, not a claim that public CI has been qualified. The
historical sibling-checkout workflow in `docs/legacy-ci-github.yml` is inert;
do not restore its shared-cache/toolchain mutation behavior.
