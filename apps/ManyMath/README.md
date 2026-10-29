# ManyMath

The ManyMath web distribution contains a website and an editor:

- `/` is the ManyMath LLC website and product directory.
- `/edit/` is the ManyUI LaTeX editor powered by the RaTeX WebAssembly engine.

The editor keeps multiple documents in local device storage, includes built-in
templates, and imports or exports standard `.tex` files. Formatting snippets,
document counts, formula diagnostics, and exact click-to-source selection are
available in desktop and compact layouts. Use Render or `Ctrl`/`Cmd`+`Enter`
to update the preview, or enable Auto render to update it as you type.
This release does not include accounts, collaboration, or cloud storage.

The document parser supports a subset of LaTeX around the RaTeX math engine: document metadata and `\maketitle`, sections, paragraphs,
inline math, basic emphasis, single-level lists, comments, and common display
math delimiters and environments.

## Build the web distribution

From the ManyMath repository root:

```sh
./apps/ManyMath/tool/build_web.sh
./apps/ManyMath/tool/verify_web_dist.sh
```

The build script compiles the RaTeX WASM module, builds Flutter with a
`/edit/` base href, and assembles the company site and editor under
`apps/ManyMath/build/dist`.

To preview the build locally:

```sh
python3 -m http.server 8080 --directory apps/ManyMath/build/dist
```

Open `http://127.0.0.1:8080/` for the company home or
`http://127.0.0.1:8080/edit/` for the editor.

The production host must serve `.wasm` files as `application/wasm` and must not
rewrite missing JavaScript or WASM files to either HTML entry point. The smoke
script verifies those conditions using a local static server.

## Develop the Flutter editor

The workspace uses published RaTeX packages and a public ManyUI Git revision.
No private repository or sibling checkout is required. Run
`flutter pub get --enforce-lockfile` and `python3 tool/integration.py` from the
repository root before building. See
[`docs/integration-boundaries.md`](../../docs/integration-boundaries.md).

```sh
bash tool/build_wasm.sh
cd apps/ManyMath
flutter run -d chrome
```

Native desktop targets use the same editor shell; Cargokit builds the Rust
engine for supported platforms.
