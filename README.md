# ManyMath

This repository contains the ManyMath editor and website:

- `apps/ManyMath` is the local-first Flutter LaTeX editor.
- `apps/ManyMath/site` is the ManyMath.com company and product website.
- `apps/ManyMath/tool` builds the site and editor into one static distribution.

The editor uses ManyUI and RaTeX. It builds without
private repositories or sibling checkouts. This branch contains the standalone
editor, parser, export tools and website. The optional review workspace is
maintained separately on `feature/review-on-editor`; it is not included here.
See [dependency and fixture ownership](docs/integration-boundaries.md).

## Develop

```sh
flutter pub get --enforce-lockfile
python3 tool/integration.py
flutter analyze --no-pub apps/ManyMath
export RUSTUP_TOOLCHAIN=1.94.0
export CARGO_HOME="$PWD/.dart_tool/cargo-home"
export RATEX_LIB="$(python3 tool/build_engine.py native)"
flutter test --no-pub apps/ManyMath/test
```

Build the RaTeX WebAssembly engine before running the editor in Chrome:

```sh
./tool/build_wasm.sh
cd apps/ManyMath
flutter run -d chrome
```

## Build ManyMath.com

```sh
./apps/ManyMath/tool/build_web.sh
./apps/ManyMath/tool/verify_web_dist.sh
```

Upload the contents of `apps/ManyMath/build/dist` to the ManyMath.com static
host. The company site is served at `/` and the editor at `/edit/`.

See `apps/ManyMath/README.md` for editor features and deployment requirements.
