#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "$script_dir/.." && pwd)"
site_dir="$app_dir/site"
flutter_dir="$app_dir/build/web"
dist_dir="$app_dir/build/dist"
staging_dir="$app_dir/build/.dist-staging-$$"

cleanup() {
  rm -rf "$staging_dir"
}
trap cleanup EXIT

required_site_assets=(
  index.html
  404.html
  styles.css
  assets/manymath-mark.svg
  assets/editor-preview.png
)
for relative_path in "${required_site_assets[@]}"; do
  test -s "$site_dir/$relative_path" || {
    echo "missing company site artifact: $site_dir/$relative_path" >&2
    exit 1
  }
done
if [[ -e "$site_dir/edit" ]]; then
  echo "the company site may not contain an edit path; /edit/ is reserved for Flutter" >&2
  exit 1
fi

required_flutter_assets=(
  index.html
  flutter_bootstrap.js
  main.dart.js
  manifest.json
  ratex_ffi.wasm
)
for relative_path in "${required_flutter_assets[@]}"; do
  test -s "$flutter_dir/$relative_path" || {
    echo "missing Flutter build artifact: $flutter_dir/$relative_path" >&2
    exit 1
  }
done

grep -Fq '<base href="/edit/">' "$flutter_dir/index.html" || {
  echo "Flutter output does not have the required /edit/ base href" >&2
  exit 1
}
if [[ -s "$flutter_dir/flutter_service_worker.js" ]]; then
  echo "Flutter output unexpectedly contains an active service worker" >&2
  exit 1
fi

wasm_magic="$(od -An -tx1 -N4 "$flutter_dir/ratex_ffi.wasm" | tr -d '[:space:]')"
if [[ "$wasm_magic" != "0061736d" ]]; then
  echo "ratex_ffi.wasm is not a valid WebAssembly binary" >&2
  exit 1
fi

rm -rf "$staging_dir"
mkdir -p "$staging_dir/edit"
cp -R "$site_dir/." "$staging_dir/"
cp -R "$flutter_dir/." "$staging_dir/edit/"

rm -rf "$dist_dir"
mv "$staging_dir" "$dist_dir"
trap - EXIT

echo "Assembled ManyMath web distribution at $dist_dir"
