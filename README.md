# ManyMath

This monorepo contains the ManyMath product surfaces:

- `apps/ManyMath` is the local-first Flutter LaTeX editor.
- `apps/ManyMath/site` is the ManyMath.com company and product website.
- `apps/ManyMath/tool` builds both surfaces into one static distribution.

The editor uses the shared ManyUI design system and the Ratex rendering engine.
Development therefore expects sibling checkouts at `../ManyUI` and `../ratex`.

## Develop

```sh
flutter pub get
flutter analyze apps/ManyMath
flutter test apps/ManyMath/test
```

Build the Ratex WebAssembly engine before running the editor in Chrome:

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

See `apps/ManyMath/README.md` for the editor and deployment contract.
