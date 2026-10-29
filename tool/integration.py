#!/usr/bin/env python3
"""Verify resolved package contracts and owned fixture provenance after pub get."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from urllib.parse import urljoin, urlsplit
from urllib.request import url2pathname

ROOT = Path(__file__).resolve().parents[1]


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def manifest():
    return json.loads((ROOT / "tool/integration-lock.json").read_text())


def package_root(name):
    config = ROOT / ".dart_tool/package_config.json"
    packages = json.loads(config.read_text())["packages"]
    item = next(item for item in packages if item["name"] == name)
    uri = urlsplit(urljoin(config.as_uri(), item["rootUri"]))
    if uri.scheme != "file" or uri.netloc:
        raise ValueError("Package source must be a local directory")
    return Path(url2pathname(uri.path)).resolve()


def resolved_packages():
    # Let pub interpret its lockfile and overrides; do not implement a second
    # lockfile parser. Run pub get --enforce-lockfile before this verification
    # to enforce the committed hosted versions and archive checksums.
    dart = shutil.which("dart")
    if dart is None:
        raise RuntimeError("Dart is required to inspect resolved hosted packages")
    result = subprocess.check_output([dart, "pub", "deps", "--json"], cwd=ROOT)
    return {item["name"]: item for item in json.loads(result)["packages"]}


def verify():
    lock = manifest()
    if lock["schema"] != 1:
        raise ValueError("Unsupported integration manifest")
    checkouts = {}
    packages = {}
    resolved = None
    for name, expected in lock["dependencies"].items():
        source = package_root(name)
        packages[name] = source
        if expected.get("source", "git") == "hosted":
            if resolved is None:
                resolved = resolved_packages()
            actual = resolved.get(name, {})
            if actual.get("source") != "hosted" or actual.get("version") != expected["version"]:
                raise ValueError(f"Package differs from hosted dependency contract: {name}")
            continue
        if expected.get("source", "git") != "git":
            raise ValueError(f"Unsupported package source: {name}")
        checkout = Path(git(source, "rev-parse", "--show-toplevel").decode().strip()).resolve()
        if source != checkout / expected["path"]:
            raise ValueError(f"Unexpected package location: {name}")
        if git(checkout, "rev-parse", "HEAD").decode().strip() != expected["revision"]:
            raise ValueError(f"Package differs from immutable integration pin: {name}")
        if git(checkout, "status", "--porcelain", "--untracked-files=all", "--", expected["path"]).strip():
            raise ValueError(f"Package source has local modifications: {name}")
        checkouts[name] = checkout
    for fixture in lock["fixtures"]:
        expected = lock["dependencies"][fixture["dependency"]]
        if expected.get("source", "git") == "hosted":
            upstream = (packages[fixture["dependency"]] / fixture["source_path"]).read_bytes()
        else:
            upstream = git(checkouts[fixture["dependency"]], "show", expected["revision"] + ":" + fixture["source_path"])
        local = (ROOT / fixture["local_path"]).read_bytes()
        if hashlib.sha256(upstream).hexdigest() != fixture["sha256"] or local != upstream:
            raise ValueError(f"Versioned fixture differs from its pinned source: {fixture['local_path']}")
    return lock


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", help="Print a verified resolved package directory")
    args = parser.parse_args()
    lock = verify()
    if args.package:
        if args.package not in lock["dependencies"]:
            raise ValueError("Package is not part of the reviewed integration")
        print(package_root(args.package))
    else:
        print("Resolved package contracts and versioned fixture bytes verified.")


if __name__ == "__main__":
    main()
