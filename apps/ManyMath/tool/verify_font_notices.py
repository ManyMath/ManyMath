#!/usr/bin/env python3
"""Check exact font notices and preserved WOFF2 bytes in a site/distribution."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
for family in ("inter", "jetbrains-mono"):
    directory = root / family
    provenance = json.loads((directory / "PROVENANCE.json").read_text())
    if hashlib.sha256((directory / "OFL.txt").read_bytes()).hexdigest() != provenance["license"]["sha256"]:
        raise ValueError(f"{family} license drift")
    fonts = {name: digest for name, digest in provenance["source_font_files_sha256"].items() if name.endswith(".woff2")}
    if len(fonts) != 2:
        raise ValueError(f"{family} must declare both installed WOFF2 fonts")
    for name, digest in fonts.items():
        if Path(name).name != name or hashlib.sha256((directory / name).read_bytes()).hexdigest() != digest:
            raise ValueError(f"{family}/{name} font drift")
print("Verified font license digests and all four installed WOFF2 files")
