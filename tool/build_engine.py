#!/usr/bin/env python3
"""Build the resolved renderer package without a sibling or shared SDK install."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

from integration import ROOT, package_root, verify


def run(command, env):
    subprocess.run(command, cwd=ROOT, env=env, stdout=sys.stderr, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=["native", "wasm"])
    args = parser.parse_args()
    verify()
    source = package_root("ratex") / "rust/Cargo.toml"
    target = Path(os.environ.get("CARGO_TARGET_DIR", ROOT / ".dart_tool/ratex-target")).resolve()
    env = dict(os.environ, CARGO_TARGET_DIR=str(target))
    env.setdefault("RUSTUP_TOOLCHAIN", "1.94.0")
    command = ["cargo", "build", "--locked", "--manifest-path", str(source)]
    if args.target == "native":
        run(command, env)
        library = "ratex_ffi.dll" if sys.platform == "win32" else "libratex_ffi.dylib" if sys.platform == "darwin" else "libratex_ffi.so"
        output = target / "debug" / library
    else:
        installed = subprocess.check_output(["rustup", "target", "list", "--installed"], env=env, text=True).splitlines()
        if "wasm32-unknown-unknown" not in installed:
            raise RuntimeError("Provision wasm32-unknown-unknown for the selected toolchain before building")
        run(command + ["--profile", "wasm-release", "--no-default-features", "--target", "wasm32-unknown-unknown"], env)
        built = target / "wasm32-unknown-unknown/wasm-release/ratex_ffi.wasm"
        output = ROOT / "apps/ManyMath/web/ratex_ffi.wasm"
        output.parent.mkdir(parents=True, exist_ok=True)
        if shutil.which("wasm-opt"):
            run(["wasm-opt", "-Oz", "--enable-bulk-memory", "--enable-multivalue", "--enable-mutable-globals", "--enable-nontrapping-float-to-int", "--enable-reference-types", "--enable-sign-ext", "-o", str(output), str(built)], env)
        else:
            print("wasm-opt unavailable: retaining the size-profile compiler output", file=sys.stderr)
            shutil.copyfile(built, output)
        run(["node", "-e", "const fs=require('fs'); const m=new WebAssembly.Module(fs.readFileSync(process.argv[1])); if(WebAssembly.Module.imports(m).length) throw Error('Renderer requires external imports');", str(output)], env)
    if not output.is_file() or output.stat().st_size == 0:
        raise RuntimeError("Renderer build did not produce the expected artifact")
    print(output)


if __name__ == "__main__":
    main()
