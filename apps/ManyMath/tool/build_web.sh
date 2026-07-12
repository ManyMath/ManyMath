#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "$script_dir/.." && pwd)"
repo_root="$(cd "$app_dir/../.." && pwd)"
manyui_dir="$repo_root/../ManyUI/manyui"

command -v flutter >/dev/null 2>&1 || {
  echo "flutter is required to build ManyMath" >&2
  exit 1
}
test -s "$manyui_dir/pubspec.yaml" || {
  echo "missing sibling ManyUI package: $manyui_dir" >&2
  echo "check out ManyUI beside Ratex before building ManyMath" >&2
  exit 1
}

"$repo_root/tool/build_wasm.sh"

rm -rf "$app_dir/build/web"
(
  cd "$app_dir"
  flutter build web \
    --release \
    --base-href=/edit/ \
    --pwa-strategy=none \
    --no-web-resources-cdn \
    --no-wasm-dry-run
)

"$script_dir/assemble_web_dist.sh"
