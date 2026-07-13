#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "$script_dir/.." && pwd)"
dist_dir="${1:-$app_dir/build/dist}"
server_log="${TMPDIR:-/tmp}/manymath-web-smoke-$$.log"
download_dir="${TMPDIR:-/tmp}/manymath-web-smoke-$$"
server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$download_dir" "$server_log"
}
trap cleanup EXIT

for command in curl python3; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "$command is required to verify the ManyMath web distribution" >&2
    exit 1
  }
done

port="${MANYMATH_SMOKE_PORT:-$(python3 -c '
import socket

with socket.socket() as server:
    server.bind(("127.0.0.1", 0))
    print(server.getsockname()[1])
')}"

required_files=(
  index.html
  404.html
  styles.css
  assets/manymath-mark.svg
  assets/editor-preview.png
  edit/index.html
  edit/flutter_bootstrap.js
  edit/main.dart.js
  edit/ratex_ffi.wasm
)
for relative_path in "${required_files[@]}"; do
  test -s "$dist_dir/$relative_path" || {
    echo "missing distribution artifact: $dist_dir/$relative_path" >&2
    exit 1
  }
done

grep -Fq '<meta name="robots" content="noindex">' "$dist_dir/404.html" || {
  echo "distribution 404 page must be excluded from indexing" >&2
  exit 1
}
if cmp -s "$dist_dir/404.html" "$dist_dir/index.html"; then
  echo "distribution 404 page must not be the site entry point" >&2
  exit 1
fi

grep -Fq '<base href="/edit/">' "$dist_dir/edit/index.html" || {
  echo "composed editor does not have the required /edit/ base href" >&2
  exit 1
}
if [[ -s "$dist_dir/edit/flutter_service_worker.js" ]]; then
  echo "composed editor unexpectedly contains an active service worker" >&2
  exit 1
fi

for url in \
  'https://manymatrix.com/' \
  'https://manykee.com/' \
  'https://manytype.com/' \
  'https://manytier.com/'; do
  grep -Fq "href=\"$url\"" "$dist_dir/index.html" || {
    echo "landing page is missing product link: $url" >&2
    exit 1
  }
done

mkdir -p "$download_dir"
python3 -m http.server "$port" \
  --bind 127.0.0.1 \
  --directory "$dist_dir" >"$server_log" 2>&1 &
server_pid=$!

for _ in $(seq 1 50); do
  if curl --fail --silent --show-error "http://127.0.0.1:$port/" \
    --output "$download_dir/site.html" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
if ! kill -0 "$server_pid" 2>/dev/null; then
  cat "$server_log" >&2
  echo "ManyMath distribution server failed to start" >&2
  exit 1
fi

curl --fail --silent --show-error "http://127.0.0.1:$port/edit/" \
  --output "$download_dir/editor.html"
curl --fail --silent --show-error "http://127.0.0.1:$port/styles.css" \
  --output "$download_dir/styles.css"
curl --fail --silent --show-error "http://127.0.0.1:$port/assets/manymath-mark.svg" \
  --output "$download_dir/manymath-mark.svg"
curl --fail --silent --show-error "http://127.0.0.1:$port/assets/editor-preview.png" \
  --output "$download_dir/editor-preview.png"
curl --fail --silent --show-error "http://127.0.0.1:$port/edit/main.dart.js" \
  --output "$download_dir/main.dart.js"
curl --fail --silent --show-error \
  --dump-header "$download_dir/wasm.headers" \
  "http://127.0.0.1:$port/edit/ratex_ffi.wasm" \
  --output "$download_dir/ratex_ffi.wasm"

grep -Fq '<base href="/edit/">' "$download_dir/editor.html"
if grep -Eiq '<!doctype html|<html' "$download_dir/styles.css"; then
  echo "/styles.css returned HTML" >&2
  exit 1
fi
if ! grep -Fq '<svg' "$download_dir/manymath-mark.svg"; then
  echo "/assets/manymath-mark.svg is not an SVG image" >&2
  exit 1
fi
preview_magic="$(od -An -tx1 -N8 "$download_dir/editor-preview.png" | tr -d '[:space:]')"
if [[ "$preview_magic" != "89504e470d0a1a0a" ]]; then
  echo "served editor-preview.png is not a valid PNG image" >&2
  exit 1
fi
if grep -Eiq '<!doctype html|<html' "$download_dir/main.dart.js"; then
  echo "/edit/main.dart.js returned HTML" >&2
  exit 1
fi
wasm_magic="$(od -An -tx1 -N4 "$download_dir/ratex_ffi.wasm" | tr -d '[:space:]')"
if [[ "$wasm_magic" != "0061736d" ]]; then
  echo "served ratex_ffi.wasm is not a valid WebAssembly binary" >&2
  exit 1
fi
grep -Eiq '^Content-Type: application/wasm([[:space:]]*;|[[:space:]]*$)' \
  "$download_dir/wasm.headers" || {
  echo "served RaTeX WebAssembly does not use the application/wasm content type" >&2
  exit 1
}

for missing_path in edit/missing.js edit/missing.wasm; do
  status="$({ curl --silent --show-error \
    --output "$download_dir/missing" \
    --write-out '%{http_code}' \
    "http://127.0.0.1:$port/$missing_path"; } || true)"
  if [[ "$status" != "404" ]]; then
    echo "/$missing_path returned $status instead of 404" >&2
    exit 1
  fi
  if cmp -s "$download_dir/missing" "$download_dir/site.html" || \
    cmp -s "$download_dir/missing" "$download_dir/editor.html"; then
    echo "/$missing_path fell back to an application entry point" >&2
    exit 1
  fi
done

echo "Verified ManyMath company site at / and editor at /edit/."
