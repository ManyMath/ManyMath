#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ratex_root="${RATEX_ROOT:-$root/../ratex}"
crate="$ratex_root/native/ratex-ffi"
wasm="$crate/target/wasm32-unknown-unknown/release/ratex_ffi.wasm"
destination="$root/apps/ManyMath/web/ratex_ffi.wasm"

test -s "$crate/Cargo.toml" || {
  echo "missing sibling Ratex checkout: $ratex_root" >&2
  exit 1
}

if ! rustup target list --installed --toolchain stable | grep -q wasm32-unknown-unknown; then
  echo "Installing the wasm32-unknown-unknown target for the stable toolchain..."
  rustup target add wasm32-unknown-unknown --toolchain stable
fi

(cd "$crate" && cargo build --release --target wasm32-unknown-unknown)

mkdir -p "$(dirname "$destination")"
cp "$wasm" "$destination"
echo "Copied $(basename "$wasm") -> ${destination#"$root"/}"
